class SubscriptionPlan::RenewalForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :actual_amount, :decimal
  attribute :admin_fee, :decimal
  attribute :paid_at, :date
  attribute :update_default_account, :boolean, default: false
  attribute :category_id, :string

  attr_accessor :subscription_plan, :account_id, :payment_method, :notes, :cycle_number, :billing_period_start, :billing_period_end, :template_amount, :currency

  validates :subscription_plan, :account_id, :actual_amount, :paid_at, :category_id, presence: true
  validates :actual_amount, numericality: { greater_than: 0 }
  validates :admin_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :account_belongs_to_subscription_family
  validate :category_belongs_to_subscription_family

  def create
    self.category_id ||= default_category_id

    return nil unless valid?

    renewal = nil
    entry = nil

    ActiveRecord::Base.transaction do
      # 1. Update the master default account if requested
      if update_default_account
        subscription_plan.update!(account_id: account_id)
      end

      # 2. Create the Entry -> Transaction (proper pipeline)
      entry = create_entry!

      # 3. Create the SubscriptionRenewal record
      renewal = create_renewal!(entry)

      # 4. Advance the subscription's next_billing_at using smart date math
      subscription_plan.mark_as_renewed!(paid_at)
    end

    if renewal && entry
      # OPTIMISTIC UPDATE: Immediate balance update for smooth UI experience
      account = payment_account
      entry_amount = entry.amount
      entry_date = entry.date
      entry_currency = entry.currency

      if entry_currency == account.currency &&
         entry_date >= 30.days.ago.to_date &&
         account.balances.any? &&
         !account.precious_metal?

        flows_factor = account.asset? ? 1 : -1
        balance_change = -entry_amount * flows_factor
        new_balance = account.balance + balance_change

        account.update_columns(
          balance: new_balance,
          updated_at: Time.current
        )

        account.broadcast_replace_to(
          account.family,
          target: "account_#{account.id}",
          partial: "accounts/account",
          locals: { account: account.reload }
        )
      end
    end

    renewal
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    nil
  end

  def default_category_id
    return nil unless subscription_plan.present?

    # 1. Last renewal's entry category
    last_renewal = subscription_plan.subscription_renewals.paid.order(paid_at: :desc).first
    if last_renewal && last_renewal.entry&.entryable&.respond_to?(:category_id)
      return last_renewal.entry.entryable.category_id
    end

    # 2. Existing "Subscription Fees" category
    category = family.categories.find_by(name: "Subscription Fees", classification: "expense")
    return category.id if category.present?

    # 3. First expense category
    family.categories.where(classification: "expense").first&.id
  end

  private

    def family
      subscription_plan.family
    end

    def category
      @category ||= family.categories.find_by(id: category_id)
    end

    def payment_account
      @payment_account ||= family.accounts.find_by(id: account_id)
    end

    def account_belongs_to_subscription_family
      return if account_id.blank? || subscription_plan.blank?
      return if payment_account.present?

      errors.add(:account_id, "is invalid")
    end

    def category_belongs_to_subscription_family
      return if category_id.blank? || subscription_plan.blank?
      return if category.present?

      errors.add(:category_id, "is invalid")
    end

    def total_deduction
      (actual_amount || 0) + (admin_fee || 0)
    end

    def create_entry!
      account = payment_account

      account.entries.create!(
        name: "Subscription: #{subscription_plan.name}",
        date: paid_at,
        amount: total_deduction, # Positive for expense (decreases asset balance)
        currency: subscription_plan.currency,
        notes: notes,
        entryable: Transaction.new(
          kind: "standard",
          category: category,
          merchant: subscription_plan.merchant
        )
      )
    end

    def create_renewal!(entry)
      period_start = billing_period_start || subscription_plan.next_billing_at || paid_at

      subscription_plan.subscription_renewals.create!(
        cycle_number: cycle_number || subscription_plan.next_cycle_number,
        account_id: account_id,
        entry_id: entry.id,
        billing_period_start: period_start,
        billing_period_end: billing_period_end || subscription_plan.calculate_next_billing_date || period_start,
        paid_at: paid_at,
        template_amount: template_amount || subscription_plan.amount,
        actual_amount: actual_amount,
        admin_fee: admin_fee || 0,
        currency: currency || subscription_plan.currency,
        status: "paid",
        payment_method: payment_method,
        notes: notes
      )
    end
end
