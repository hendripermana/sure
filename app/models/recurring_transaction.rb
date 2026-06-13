require "digest"

class RecurringTransaction < ApplicationRecord
  include Monetizable

  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :destination_account, optional: true, class_name: "Account"
  belongs_to :merchant, optional: true
  has_many :audit_logs, as: :auditable, dependent: :delete_all

  monetize :amount
  monetize :expected_amount_min, allow_nil: true
  monetize :expected_amount_max, allow_nil: true
  monetize :expected_amount_avg, allow_nil: true

  enum :status, { active: "active", inactive: "inactive", ignored: "ignored" }

  validates :amount, presence: true
  validates :currency, presence: true
  validates :expected_day_of_month, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 31 }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :occurrence_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :identity_signature, presence: true, uniqueness: { scope: :family_id }, if: -> { has_attribute?(:identity_signature) }
  validate :merchant_or_name_present
  validate :amount_variance_consistency
  validate :transfer_endpoints_consistent

  before_validation :assign_identity_signature, if: -> { has_attribute?(:identity_signature) }

  def merchant_or_name_present
    if merchant_id.blank? && name.blank?
      errors.add(:base, "Either merchant or name must be present")
    end
  end

  def amount_variance_consistency
    return unless manual?

    if expected_amount_min.present? && expected_amount_max.present?
      if expected_amount_min > expected_amount_max
        errors.add(:expected_amount_min, "cannot be greater than expected_amount_max")
      end
    end
  end

  def transfer_endpoints_consistent
    return if destination_account_id.blank?

    if account.blank?
      errors.add(:account, "must exist")
    elsif destination_account.blank?
      errors.add(:destination_account, "must exist")
    elsif account_id == destination_account_id
      errors.add(:destination_account, "cannot be the same as the source account")
    elsif account.family_id != destination_account.family_id || family_id != account.family_id
      errors.add(:destination_account, "must belong to the same family as the source account")
    end
  end

  def transfer?
    destination_account_id.present?
  end

  def schedule
    Recurring::Schedule.from_recurring_transaction(self)
  end

  def self.identity_signature_for(account_id:, destination_account_id:, merchant_id:, name:, amount:, currency:)
    return nil if amount.blank? || currency.blank?

    normalized_name = name.to_s.squish.downcase
    normalized_amount = BigDecimal(amount.to_s).round(2).to_s("F")
    raw_identity = [
      "source:#{account_id || 'any'}",
      "destination:#{destination_account_id || 'none'}",
      "merchant:#{merchant_id || 'none'}",
      "name:#{normalized_name}",
      "amount:#{normalized_amount}",
      "currency:#{currency.to_s.upcase}"
    ].join("|")

    Digest::SHA256.hexdigest(raw_identity)
  end

  scope :for_family, ->(family) { where(family: family) }
  scope :visible, -> { where.not(status: "ignored") }
  scope :expected_soon, -> { active.where("next_expected_date <= ?", 1.month.from_now) }

  # Class methods for identification and cleanup
  def self.identify_patterns_for(family)
    Identifier.new(family).identify_recurring_patterns
  end

  def self.schedule_identification_for(family)
    IdentifyRecurringTransactionsJob.schedule_for(family)
  end

  def self.cleanup_stale_for(family)
    Cleaner.new(family).cleanup_stale_transactions
  end

  # Create a manual recurring transaction from an existing transaction
  # Automatically calculates amount variance from past 6 months of matching transactions
  def self.create_from_transaction(transaction, day_of_month: nil)
    family = transaction.entry.account.family
    entry = transaction.entry
    merchant = transaction.merchant

    # Determine day of month if not provided
    day_of_month ||= entry.date.day

    # Find past matching transactions to calculate variance
    # Look back 6 months
    start_date = 6.months.ago.to_date

    query = entry.account.entries
      .joins(transaction_join_sql)
      .where(entryable_type: "Transaction")
      .where(currency: entry.currency)
      .where.not(transactions: { kind: Transaction::TRANSFER_KINDS })
      .where("entries.date >= ?", start_date)
      .where("entries.date <= ?", entry.date)
      .where("EXTRACT(DAY FROM entries.date) BETWEEN ? AND ?",
             [ day_of_month - 5, 1 ].max,
             [ day_of_month + 5, 31 ].min)

    if merchant.present?
      matching_entries = query.where(transactions: { merchant_id: merchant.id }).to_a
    else
      matching_entries = query.where(name: entry.name).to_a
    end

    # Include the current transaction if not already in list
    unless matching_entries.find { |e| e.id == entry.id }
      matching_entries << entry
    end

    # Calculate amounts
    amounts = matching_entries.map(&:amount)
    min_amount = amounts.min
    max_amount = amounts.max
    avg_amount = amounts.sum / amounts.size

    # Create the recurring transaction
    create!(
      family: family,
      account: entry.account,
      merchant: merchant,
      name: merchant.present? ? nil : entry.name,
      amount: entry.amount, # Use current amount as base
      currency: entry.currency,
      expected_day_of_month: day_of_month,
      last_occurrence_date: entry.date,
      next_expected_date: entry.date.next_month, # Simple projection, will be refined
      occurrence_count: amounts.size,
      status: "active",
      manual: true,
      expected_amount_min: min_amount,
      expected_amount_max: max_amount,
      expected_amount_avg: avg_amount
    )
  end

  def self.create_from_transfer(transfer)
    outflow_entry = transfer.outflow_transaction&.entry
    inflow_entry = transfer.inflow_transaction&.entry
    raise ArgumentError, "Transfer is missing one of its entries" unless outflow_entry && inflow_entry

    source_account = outflow_entry.account
    destination_account = inflow_entry.account
    raise ArgumentError, "Transfer accounts must belong to the same family" unless source_account.family_id == destination_account.family_id

    create!(
      family: source_account.family,
      account: source_account,
      destination_account: destination_account,
      name: transfer.name,
      amount: outflow_entry.amount,
      currency: outflow_entry.currency,
      expected_day_of_month: outflow_entry.date.day,
      last_occurrence_date: outflow_entry.date,
      next_expected_date: next_date_for_day(outflow_entry.date.day),
      occurrence_count: 1,
      status: "active",
      manual: true
    )
  end

  def self.next_date_for_day(day, from: Date.current)
    next_month = from.next_month
    Date.new(next_month.year, next_month.month, day)
  rescue ArgumentError
    next_month.end_of_month
  end

  # Find matching transactions for this recurring pattern
  def matching_transactions
    return transfer_matching_transactions if transfer?

    entries = (account || family).entries
      .joins(self.class.transaction_join_sql)
      .where(entryable_type: "Transaction")
      .where(currency: currency)
      .where.not(transactions: { kind: Transaction::TRANSFER_KINDS })

    # For manual recurring transactions, we allow amount variance
    if manual? && expected_amount_min.present? && expected_amount_max.present?
      # Allow 10% buffer outside the observed range or at least 5 units
      buffer = [ expected_amount_avg * 0.1, 5 ].max
      entries = entries.where("entries.amount BETWEEN ? AND ?",
                             expected_amount_min - buffer,
                             expected_amount_max + buffer)
    else
      entries = entries.where("entries.amount = ?", amount)
    end

    entries = entries.where("EXTRACT(DAY FROM entries.date) BETWEEN ? AND ?",
             [ expected_day_of_month - 2, 1 ].max,
             [ expected_day_of_month + 2, 31 ].min)
      .order(date: :desc)

    # Filter by merchant or name
    if merchant_id.present?
      entries.where(transactions: { merchant_id: merchant_id })
    else
      entries.where(name: name)
    end
  end

  def self.transaction_join_sql
    <<~SQL.squish
      INNER JOIN transactions
        ON transactions.id = entries.entryable_id
        AND entries.entryable_type = 'Transaction'
    SQL
  end

  # Check if this recurring transaction should be marked inactive
  def should_be_inactive?
    return false if ignored?
    return false if last_occurrence_date.nil?
    last_occurrence_date < 2.months.ago
  end

  # Mark as inactive
  def mark_inactive!
    update!(status: "inactive")
  end

  # Mark as active
  def mark_active!
    update!(status: "active")
  end

  def ignore!
    ActiveRecord::Base.transaction do
      create_suppression!
      update!(status: "ignored")
    end
  end

  def restore!
    ActiveRecord::Base.transaction do
      RecurringTransactionSuppression.where(
        family: family,
        signature: suppression_signatures
      ).delete_all
      update!(status: "active")
    end
  end

  def confirm_as_recurring!
    with_lock do
      update!(manual: true, status: "active")
      Recurring::EventRecorder.record!(
        record: self,
        event: "recurring.confirmed",
        key: "confirmed",
        title: "Confirmed recurring pattern",
        detail: "User confirmed this detected pattern as a recurring commitment.",
        metadata: { confidence: Recurring::Assessment.new(self).score }
      )
    end
  end

  def recurring_assessment
    Recurring::Assessment.new(self)
  end

  def mark_as_transfer!(destination_account)
    raise ArgumentError, "A source account is required" if account.blank?
    raise ArgumentError, "Destination account must belong to the same family" if destination_account&.family_id != family_id
    raise ArgumentError, "Destination account must differ from source account" if destination_account.id == account_id

    with_lock do
      update!(
        destination_account: destination_account,
        manual: true,
        status: "active"
      )
      Recurring::EventRecorder.record!(
        record: self,
        event: "recurring.classified_transfer",
        key: "classified-transfer:#{destination_account.id}",
        title: "Classified as recurring transfer",
        detail: "This pattern now tracks transfers from #{account.name} to #{destination_account.name}.",
        metadata: {
          source_account_id: account_id,
          destination_account_id: destination_account.id
        }
      )
    end
  end

  def create_subscription_plan!
    raise ArgumentError, "Only recurring expenses can become subscription plans" unless subscription_candidate?

    existing = matching_subscription_plan

    ActiveRecord::Base.transaction do
      if existing
        ignore!
        existing
      else
        plan = family.subscription_plans.create!(
          account: inferred_account!,
          merchant: merchant,
          name: subscription_name,
          amount: amount,
          currency: currency,
          billing_cycle: "monthly",
          status: "active",
          payment_method: "manual",
          started_at: last_occurrence_date,
          next_billing_at: next_expected_date,
          auto_renew: true,
          metadata: {
            source: {
              type: self.class.name,
              id: id,
              converted_at: Time.current.iso8601
            }
          }
        )

        ignore!
        plan
      end
    end
  end

  def subscription_candidate?
    !transfer? && amount.positive? && next_expected_date.present? && last_occurrence_date.present?
  end

  def suppressed_signature?
    RecurringTransactionSuppression.suppressed?(
      family: family,
      account_id: account_id,
      merchant_id: merchant_id,
      name: name,
      amount: amount,
      currency: currency
    )
  end

  # Update based on a new transaction occurrence
  # Update based on a new transaction occurrence
  def record_occurrence!(transaction_date, transaction_amount = nil)
    return false if ignored?

    self.last_occurrence_date = transaction_date
    self.next_expected_date = calculate_next_expected_date(transaction_date)
    self.occurrence_count += 1
    self.status = "active"

    # Update variance stats if amount provided and manual
    if manual? && transaction_amount.present?
      self.expected_amount_min = [ expected_amount_min || amount, transaction_amount ].min
      self.expected_amount_max = [ expected_amount_max || amount, transaction_amount ].max

      # Weighted average update
      current_avg = expected_amount_avg || amount
      # New average = ((old_avg * (count-1)) + new_amount) / count
      # We use occurrence_count which was just incremented
      self.expected_amount_avg = ((current_avg * (occurrence_count - 1)) + transaction_amount) / occurrence_count
    end

    save!
  end

  # Calculate the next expected date based on the last occurrence
  def calculate_next_expected_date(from_date = last_occurrence_date)
    # Start with next month
    next_month = from_date.next_month

    # Try to use the expected day of month
    begin
      Date.new(next_month.year, next_month.month, expected_day_of_month)
    rescue ArgumentError
      # If day doesn't exist in month (e.g., 31st in February), use last day of month
      next_month.end_of_month
    end
  end

  # Get the projected transaction for display
  def projected_entry
    return nil unless active?
    return nil unless next_expected_date.future?

    # Use average amount for manual recurring transactions if available
    projected_amount = (manual? && expected_amount_avg.present?) ? expected_amount_avg : amount

    OpenStruct.new(
      date: next_expected_date,
      amount: projected_amount,
      currency: currency,
      merchant: merchant,
      name: merchant.present? ? merchant.name : name,
      recurring: true,
      projected: true,
      transfer: transfer?,
      source_account: account,
      destination_account: destination_account
    )
  end

  def has_amount_variance?
    return false unless manual?
    return false unless expected_amount_min.present? && expected_amount_max.present?
    expected_amount_min != expected_amount_max
  end

  private
    def transfer_matching_transactions
      return Entry.none unless account && destination_account

      source_entries = account.entries
        .where(entryable_type: "Transaction", currency: currency, amount: amount)
        .where(
          "EXTRACT(DAY FROM entries.date) BETWEEN ? AND ?",
          [ expected_day_of_month - 2, 1 ].max,
          [ expected_day_of_month + 2, 31 ].min
        )

      paired_transaction_ids = Transfer
        .where(outflow_transaction_id: source_entries.select(:entryable_id))
        .where(
          inflow_transaction_id: destination_account.entries
            .where(entryable_type: "Transaction")
            .select(:entryable_id)
        )
        .pluck(:outflow_transaction_id)

      source_entries.where(entryable_id: paired_transaction_ids).order(date: :desc)
    end

    def assign_identity_signature
      self.identity_signature = self.class.identity_signature_for(
        account_id: account_id,
        destination_account_id: destination_account_id,
        merchant_id: merchant_id,
        name: name,
        amount: amount,
        currency: currency
      )
    end

    def subscription_name
      merchant&.name || name
    end

    def inferred_account!
      inferred_account = account || Array(matching_transactions).max_by(&:date)&.account
      inferred_account ||= family.accounts.first
      raise ArgumentError, "Cannot create subscription without a payment account" unless inferred_account

      inferred_account
    end

    def matching_subscription_plan
      scope = family.subscription_plans.unarchived

      if merchant_id.present?
        scope.find_by(merchant_id: merchant_id)
      else
        scope.where("LOWER(name) = ?", subscription_name.to_s.downcase)
          .find_by(amount: amount, currency: currency)
      end
    end

    def monetizable_currency
      currency
    end

    def create_suppression!
      RecurringTransactionSuppression.suppress!(
        family: family,
        account_id: account_id,
        destination_account_id: destination_account_id,
        merchant_id: merchant_id,
        name: name,
        amount: amount,
        currency: currency,
        expected_day_of_month: expected_day_of_month,
        metadata: {
          recurring_transaction_id: id
        }.compact
      )
    end

    def suppression_signatures
      [ account_id, nil ].uniq.filter_map do |suppression_account_id|
        RecurringTransactionSuppression.signature_for(
          account_id: suppression_account_id,
          destination_account_id: destination_account_id,
          merchant_id: merchant_id,
          name: name,
          amount: amount,
          currency: currency
        )
      end
    end
end
