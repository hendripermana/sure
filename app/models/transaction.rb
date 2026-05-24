class Transaction < ApplicationRecord
  include Entryable, Transferable, Ruleable

  belongs_to :category, optional: true
  belongs_to :merchant, optional: true

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  accepts_nested_attributes_for :taggings, allow_destroy: true

  enum :kind, {
    standard: "standard", # A regular transaction, included in budget analytics
    funds_movement: "funds_movement", # Movement of funds between accounts, excluded from budget analytics
    cc_payment: "cc_payment", # A CC payment, excluded from budget analytics (CC payments offset the sum of expense transactions)
    loan_payment: "loan_payment", # A payment to a Loan account, treated as an expense in budgets
    one_time: "one_time", # A one-time expense/income, excluded from budget analytics
    # Indonesian and Islamic finance transaction types
    loan_disbursement: "loan_disbursement", # When you receive loan money (inflow)
    personal_lending: "personal_lending", # When you lend money to friends (outflow)
    personal_borrowing: "personal_borrowing", # When you borrow from friends (inflow)
    zakat_payment: "zakat_payment", # Islamic obligatory charity (expense)
    infaq_sadaqah: "infaq_sadaqah", # Voluntary Islamic charity (expense)
    profit_sharing: "profit_sharing", # Islamic profit sharing income
    margin_payment: "margin_payment" # Islamic margin-based payments (like Murabaha)
  }

  # Pending transaction scopes - filter based on provider pending flags in extra JSONB
  # Works with any provider that stores pending status in extra["provider_name"]["pending"]
  scope :pending, -> {
    where(<<~SQL.squish)
      (transactions.extra -> 'simplefin' ->> 'pending')::boolean = true
      OR (transactions.extra -> 'plaid' ->> 'pending')::boolean = true
    SQL
  }

  scope :excluding_pending, -> {
    where(<<~SQL.squish)
      (transactions.extra -> 'simplefin' ->> 'pending')::boolean IS DISTINCT FROM true
      AND (transactions.extra -> 'plaid' ->> 'pending')::boolean IS DISTINCT FROM true
    SQL
  }

  after_commit :apply_precious_metal_quantity_delta, on: :create
  after_commit :adjust_precious_metal_quantity_delta, on: :update
  after_commit :revert_precious_metal_quantity_delta, on: :destroy

  # Overarching grouping method for all transfer-type transactions
  def transfer?
    funds_movement? || cc_payment? || loan_payment? || personal_lending? || personal_borrowing?
  end

  # Islamic finance transaction grouping
  def islamic_finance?
    zakat_payment? || infaq_sadaqah? || profit_sharing? || margin_payment?
  end

  # Personal lending transaction grouping
  def personal_debt?
    personal_lending? || personal_borrowing?
  end

  # Check if transaction should be excluded from budget analytics
  def excluded_from_budget?
    transfer? || one_time?
  end

  def splittable?
    !transfer? && !entry.split_child? && !entry.split_parent? && !pending? && !entry.excluded?
  end

  # Check if transaction is Sharia compliant
  def sharia_compliant?
    return is_sharia_compliant unless is_sharia_compliant.nil?

    # Auto-detect based on transaction type
    islamic_finance? ||
      (personal_debt? &&
        entry&.account&.accountable&.respond_to?(:sharia_compliant?) &&
        entry.account.accountable.sharia_compliant?)
  end

  def set_category!(category)
    if category.is_a?(String)
      category = entry.account.family.categories.find_or_create_by!(
        name: category
      )
    end

    update!(category: category)
  end

  def pending?
    extra_data = extra.is_a?(Hash) ? extra : {}
    ActiveModel::Type::Boolean.new.cast(extra_data.dig("simplefin", "pending")) ||
      ActiveModel::Type::Boolean.new.cast(extra_data.dig("plaid", "pending"))
  rescue StandardError
    false
  end

  def precious_metal_details
    return nil unless extra.is_a?(Hash)

    extra["precious_metal"]
  end

  def precious_metal_transaction?
    precious_metal_details.present?
  end

  def precious_metal_action
    precious_metal_details&.fetch("action", nil)
  end

  def precious_metal_quantity
    value = precious_metal_details&.dig("quantity")
    value.present? ? value.to_d : nil
  end

  def precious_metal_unit
    precious_metal_details&.dig("unit")
  end

  def precious_metal_cash_amount
    value = precious_metal_details&.dig("cash_amount")
    value.present? ? value.to_d : nil
  end

  def precious_metal_cash_currency
    precious_metal_details&.dig("cash_currency")
  end

  # Potential duplicate matching methods
  # These help users review and resolve fuzzy-matched pending/posted pairs

  def has_potential_duplicate?
    potential_posted_match_data.present? && !potential_duplicate_dismissed?
  end

  def potential_duplicate_entry
    return nil unless has_potential_duplicate?
    Entry.find_by(id: potential_posted_match_data["entry_id"])
  end

  def potential_duplicate_reason
    potential_posted_match_data&.dig("reason")
  end

  def potential_duplicate_confidence
    potential_posted_match_data&.dig("confidence") || "medium"
  end

  def low_confidence_duplicate?
    potential_duplicate_confidence == "low"
  end

  def potential_duplicate_posted_amount
    potential_posted_match_data&.dig("posted_amount")&.to_d
  end

  def potential_duplicate_dismissed?
    potential_posted_match_data&.dig("dismissed") == true
  end

  # Merge this pending transaction with its suggested posted match
  # This DELETES the pending entry since the posted version is canonical
  def merge_with_duplicate!
    return false unless has_potential_duplicate?

    posted_entry = potential_duplicate_entry
    return false unless posted_entry

    pending_entry_id = entry.id
    pending_entry_name = entry.name

    # Delete this pending entry completely (no need to keep it around)
    entry.destroy!

    Rails.logger.info("User merged pending entry #{pending_entry_id} (#{pending_entry_name}) with posted entry #{posted_entry.id}")
    true
  end

  # Dismiss the duplicate suggestion - user says these are NOT the same transaction
  def dismiss_duplicate_suggestion!
    return false unless potential_posted_match_data.present?

    updated_extra = (extra || {}).deep_dup
    updated_extra["potential_posted_match"]["dismissed"] = true
    update!(extra: updated_extra)

    Rails.logger.info("User dismissed duplicate suggestion for entry #{entry.id}")
    true
  end

  # Clear the duplicate suggestion entirely
  def clear_duplicate_suggestion!
    return false unless potential_posted_match_data.present?

    updated_extra = (extra || {}).deep_dup
    updated_extra.delete("potential_posted_match")
    update!(extra: updated_extra)
    true
  end

  private

    def potential_posted_match_data
      return nil unless extra.is_a?(Hash)
      extra["potential_posted_match"]
    end

    def precious_metal_quantity_delta
      value = precious_metal_details&.dig("quantity_delta")
      value.present? ? value.to_d : nil
    end

    def precious_metal_account
      return entry.account if entry&.account&.precious_metal?

      account_id = precious_metal_details&.dig("account_id")
      return if account_id.blank?

      account = Account.find_by(id: account_id)
      account if account&.precious_metal?
    end

    def apply_precious_metal_quantity_delta
      delta = precious_metal_quantity_delta
      return if delta.nil?

      account = precious_metal_account
      return unless account

      account.precious_metal.apply_quantity_delta!(delta, effective_date: entry&.date)
    end

    def adjust_precious_metal_quantity_delta
      return unless saved_change_to_extra?

      before_extra, after_extra = saved_change_to_extra
      old_delta = before_extra.is_a?(Hash) ? before_extra.dig("precious_metal", "quantity_delta") : nil
      new_delta = after_extra.is_a?(Hash) ? after_extra.dig("precious_metal", "quantity_delta") : nil
      return if old_delta == new_delta

      account = precious_metal_account
      return unless account

      old_value = old_delta.present? ? old_delta.to_d : 0
      new_value = new_delta.present? ? new_delta.to_d : 0
      account.precious_metal.apply_quantity_delta!(new_value - old_value, effective_date: entry&.date)
    end

    def revert_precious_metal_quantity_delta
      delta = precious_metal_quantity_delta
      return if delta.nil?

      account = precious_metal_account
      return unless account

      account.precious_metal.apply_quantity_delta!(delta * -1, effective_date: entry&.date)
    end
end
