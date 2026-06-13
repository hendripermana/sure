class SubscriptionPlan < ApplicationRecord
  include Monetizable
  include AuditableChanges

  track_changes_for :status, :amount, :currency, :next_billing_at, :auto_renew,
    :cancel_at_period_end, :cancelled_at, :expires_at, :payment_method

  belongs_to :family
  belongs_to :service, optional: true  # Deprecated: Use merchant instead
  belongs_to :merchant, optional: true # New: ServiceMerchant reference
  belongs_to :account

  attr_writer :interval_count, :interval_unit

  has_many :subscription_renewals, dependent: :destroy
  has_many :stripe_event_receipts, dependent: :destroy
  has_many :audit_logs, as: :auditable, dependent: :delete_all

  # Returns the associated service (ServiceMerchant or legacy Service)
  def service_merchant
    merchant || service
  end

  def schedule
    Recurring::Schedule.from_subscription(self)
  end

  def interval_count
    @interval_count || schedule.count
  end

  def interval_unit
    @interval_unit || schedule.unit
  end

  def apply_schedule_attributes
    return if @interval_count.blank? && @interval_unit.blank?

    selected_schedule = Recurring::Schedule.new(
      count: @interval_count.presence || schedule.count,
      unit: @interval_unit.presence || schedule.unit
    )
    self.billing_cycle = selected_schedule.legacy_cycle
    self.metadata = metadata.to_h.merge("schedule" => selected_schedule.to_h)
  rescue ArgumentError => error
    errors.add(:billing_cycle, error.message)
  end

  # Include monetize after associations for proper setup
  monetize :amount

  # Subscription status lifecycle
  enum :status, {
    active: "active",
    trial: "trial",
    paused: "paused",
    cancelled: "cancelled",
    expired: "expired",
    payment_failed: "payment_failed",
    pending: "pending"
  }, prefix: false

  # Billing cycle options
  enum :billing_cycle, {
    monthly: "monthly",
    annual: "annual",
    quarterly: "quarterly",
    biennial: "biennial",
    one_time: "one_time"
  }, prefix: true

  # Payment method types
  enum :payment_method, {
    auto: "auto",        # Stripe billing
    manual: "manual",    # Track manually
    cash: "cash",        # Cash payments
    bank_transfer: "bank_transfer",
    credit_card: "credit_card"
  }, prefix: true

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :amount, numericality: { greater_than: 0 }
  validates :currency, presence: true, length: { is: 3 }
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :billing_cycle, presence: true, inclusion: { in: billing_cycles.keys }
  validates :payment_method, presence: true, inclusion: { in: payment_methods.keys }
  validates :started_at, presence: true
  validates :next_billing_at, presence: true

  # Billing window validations
  validates :billing_day_start, numericality: { greater_than: 0, less_than_or_equal_to: 31 }, allow_nil: true
  validates :billing_day_end, numericality: { greater_than: 0, less_than_or_equal_to: 31 }, allow_nil: true
  validates :default_admin_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :billing_window_valid
  validate :apply_schedule_attributes
  validate :next_billing_not_before_start
  before_validation :normalize_trial_status, on: :create

  # Status-specific validations
  with_options if: -> { active? || trial? } do
    validates :next_billing_at, presence: true
    validates :auto_renew, inclusion: { in: [ true, false ] }
  end

  with_options if: -> { trial? } do
    validates :trial_ends_at, presence: true
  end

  # Scopes for business logic
  scope :active, -> { where(status: "active") }
  scope :archived, -> { where(archived: true) }
  scope :unarchived, -> { where(archived: false) }
  scope :upcoming_renewals, ->(days = 7) {
    where(next_billing_at: Date.current..(Date.current + days.days))
      .where(status: "active")
  }
  scope :overdue, -> {
    where("next_billing_at < ? AND status = ?", Date.current, "active")
  }
  scope :trial_ending, ->(days = 3) {
    where(status: "trial", trial_ends_at: Date.current..(Date.current + days.days))
  }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :expired, -> { where(status: "expired") }
  scope :payment_failed, -> { where(status: "payment_failed") }

  # Soft-delete scopes
  scope :kept, -> { where(discarded_at: nil) }
  scope :discarded, -> { where.not(discarded_at: nil) }

  # Default scope: exclude soft-deleted records
  default_scope { kept }

  # Business logic methods
  def days_until_renewal
    return 0 if next_billing_at.blank?
    [ next_billing_at - Date.current, 0 ].max.to_i
  end

  def trial_days_remaining
    return 0 unless trial? && trial_ends_at.present?
    [ trial_ends_at - Date.current, 0 ].max.to_i
  end

  def expired?
    status == "expired" || (expires_at.present? && expires_at < Date.current)
  end

  def cancelled?
    status == "cancelled" || status == "expired"
  end

  def active_or_trial?
    active? || trial?
  end

  def auto_renewal_enabled?
    auto_renew && active_or_trial?
  end

  def pending_cancellation?
    cancel_at_period_end? && !cancelled? && !expired?
  end

  def stripe_managed?
    payment_method_auto? && stripe_subscription_id.present?
  end

  def stripe_subscription_item_id
    metadata.dig("stripe", "subscription_item_id")
  end

  def stripe_pause_collection_behavior
    metadata.dig("stripe", "pause_collection", "behavior")
  end

  # Billing window support — flexible due date ranges
  def has_billing_window?
    billing_day_start.present? && billing_day_end.present?
  end

  # Compute the billing window dates for a given month
  def billing_window_for(date = Date.current)
    return nil unless has_billing_window?

    month_start = date.beginning_of_month
    window_start = safe_date(month_start.year, month_start.month, billing_day_start)
    window_end = safe_date(month_start.year, month_start.month, billing_day_end)

    window_start..window_end
  end

  # Subscription state relative to the billing window
  # Returns :upcoming, :open_for_payment, :overdue, or :paid
  def billing_state(date = Date.current)
    # Check if already paid for this cycle
    current_renewal = current_cycle_renewal
    return :paid if current_renewal&.paid?

    if has_billing_window?
      window = billing_window_for(date)
      return :upcoming if date < window.first
      return :open_for_payment if window.cover?(date)
      return :overdue if date > window.last
    else
      return :upcoming if next_billing_at.present? && date < next_billing_at
      return :overdue if next_billing_at.present? && date > next_billing_at
      return :open_for_payment
    end

    :upcoming
  end

  # Get the renewal record for the current billing cycle
  def current_cycle_renewal
    subscription_renewals.order(cycle_number: :desc).first
  end

  # Next cycle number for creating a new renewal
  def next_cycle_number
    (subscription_renewals.maximum(:cycle_number) || 0) + 1
  end

  # Build a pre-filled renewal record for the modal form
  def build_renewal(overrides = {})
    cycle = next_cycle_number
    period_start = next_billing_at || Date.current
    period_end = calculate_next_billing_date || period_start.next_month

    subscription_renewals.build({
      cycle_number: cycle,
      account_id: account_id,
      billing_period_start: period_start,
      billing_period_end: period_end,
      template_amount: amount,
      actual_amount: amount,
      admin_fee: default_admin_fee || 0,
      currency: currency,
      status: "pending"
    }.merge(overrides))
  end

  # Soft-delete
  def discard!
    update!(discarded_at: Time.current)
  end

  def undiscard!
    update!(discarded_at: nil)
  end

  def discarded?
    discarded_at.present?
  end

  def monthly_equivalent_amount
    (amount * schedule.monthly_multiplier).round(2)
  end

  def yearly_equivalent_amount
    (amount * schedule.yearly_multiplier).round(2)
  end

  def formatted_amount
    "#{currency} #{amount}"
  end

  def formatted_monthly_amount
    return "Not recurring" if schedule.once?

    monthly_amount = monthly_equivalent_amount
    "#{currency} #{monthly_amount.round(2)}/month"
  end

  def formatted_billing_cycle
    schedule.label
  end

  def status_badge_class
    case status
    when "active"
      "bg-green-100 text-green-800 theme-dark:bg-green-900/20 theme-dark:text-green-200"
    when "trial"
      "bg-blue-100 text-blue-800 theme-dark:bg-blue-900/20 theme-dark:text-blue-200"
    when "paused"
      "bg-yellow-100 text-yellow-800 theme-dark:bg-yellow-900/20 theme-dark:text-yellow-200"
    when "cancelled", "expired"
      "bg-gray-100 text-gray-800 theme-dark:bg-gray-900/40 theme-dark:text-gray-200"
    when "payment_failed"
      "bg-red-100 text-red-800 theme-dark:bg-red-900/30 theme-dark:text-red-300"
    else
      "bg-gray-100 text-gray-800 theme-dark:bg-gray-900/40 theme-dark:text-gray-200"
    end
  end

  def status_icon
    case status
    when "active"
      "✅"
    when "trial"
      "🎯"
    when "paused"
      "⏸️"
    when "cancelled", "expired"
      "❌"
    when "payment_failed"
      "⚠️"
    when "pending"
      "⏳"
    else
      "📋"
    end
  end

  # Record a manual payment coming from an Entry/Transaction and
  # advance the billing schedule when the payment is close to the
  # current billing date. This keeps subscription renewals in sync
  # with real-world payments without requiring a hard link table.
  #
  # @param paid_at [Date, Time] when the payment was made
  # @return [Boolean] true if billing was advanced, false otherwise
  def record_manual_payment!(paid_at:)
    return false unless next_billing_at.present?
    return false unless active_or_trial?

    paid_date = paid_at.to_date
    return false unless payment_date_matches_current_cycle?(paid_date)

    mark_as_renewed!(paid_at)
    true
  end

  def record_payment_entry!(entry)
    return false unless next_billing_at.present?
    return false unless active_or_trial?
    return false unless entry.amount.positive?
    return false unless entry.currency == currency
    return false unless entry.account_id == account_id
    return false if subscription_renewals.exists?(entry_id: entry.id)

    amount_tolerance = amount / 10
    return false unless (entry.amount - amount).abs <= amount_tolerance
    return false unless payment_date_matches_current_cycle?(entry.date)

    ActiveRecord::Base.transaction do
      subscription_renewals.create!(
        cycle_number: next_cycle_number,
        account: entry.account,
        entry: entry,
        billing_period_start: next_billing_at,
        billing_period_end: calculate_next_billing_date || next_billing_at,
        paid_at: entry.date,
        template_amount: amount,
        actual_amount: entry.amount,
        admin_fee: 0,
        currency: currency,
        status: "paid",
        payment_method: payment_method,
        notes: entry.notes
      )

      mark_as_renewed!(entry.date)
    end

    true
  end

  # Lifecycle management
  def mark_as_renewed!(paid_at = Date.current)
    if schedule.once?
      update!(
        status: "expired",
        auto_renew: false,
        expires_at: paid_at.to_date,
        last_renewal_at: paid_at,
        failed_payment_alert_sent: false,
        usage_count: (usage_count || 0) + 1
      )
      return
    end

    new_billing_date = calculate_next_billing_date
    raise ArgumentError, "Cannot renew subscription without a valid billing date" unless new_billing_date.present?

    update!(
      next_billing_at: new_billing_date,
      last_renewal_at: paid_at,
      failed_payment_alert_sent: false,
      usage_count: (usage_count || 0) + 1
    )
  end

  def pause!
    return update!(status: "paused") unless stripe_managed?

    stripe_subscription = update_stripe_collection(pause_collection: { behavior: "void" })
    return false unless stripe_subscription

    sync_from_stripe_subscription!(stripe_subscription)
    true
  end

  def resume!
    return update!(status: "active") unless stripe_managed?

    stripe_subscription = update_stripe_collection(pause_collection: "")
    return false unless stripe_subscription

    sync_from_stripe_subscription!(stripe_subscription)
    true
  end

  def cancel!(at_next_renewal: false)
    if stripe_managed?
      stripe_subscription = cancel_stripe_subscription(at_period_end: at_next_renewal)
      return false unless stripe_subscription

      return true
    end

    if at_next_renewal
      update!(
        status: active? || trial? ? status : "active",
        auto_renew: false,
        cancel_at_period_end: true,
        expires_at: stripe_current_period_end&.to_date || next_billing_at
      )
    else
      update!(
        status: "cancelled",
        cancelled_at: Date.current,
        auto_renew: false,
        cancel_at_period_end: false,
        expires_at: Date.current
      )
    end

    true
  end

  def undo_cancellation!
    return false unless pending_cancellation?

    if stripe_managed?
      stripe_subscription = Stripe::Subscription.update(
        stripe_subscription_id,
        cancel_at_period_end: false
      )
      sync_from_stripe_subscription!(stripe_subscription)
    else
      update!(
        cancel_at_period_end: false,
        auto_renew: true,
        expires_at: nil
      )
    end

    true
  rescue Stripe::StripeError => e
    Rails.logger.error("Failed to undo Stripe cancellation for #{name}: #{e.message}")
    errors.add(:base, "Stripe cancellation update failed: #{e.message}")
    false
  end

  def expire!
    update!(
      status: "expired",
      expires_at: Date.current
    )
  end

  def mark_payment_failed!
    update!(
      status: "payment_failed",
      failed_payment_alert_sent: true
    )
  end

  def mark_payment_successful!
    update!(
      status: "active",
      failed_payment_alert_sent: false
    )
  end

  def mark_as_trial!
    update!(
      status: "trial",
      trial_ends_at: calculate_trial_end_date
    )
  end

  def update_next_billing_date!
    update!(
      next_billing_at: calculate_next_billing_date
    )
  end

  def archive!
    update!(archived: true)
  end

  def unarchive!
    update!(archived: false)
  end

  # Integration with Stripe
  def create_stripe_subscription(customer_id)
    return false unless payment_method_auto?

    sm = service_merchant
    return false unless sm.present?

    stripe_plan = sm.respond_to?(:stripe_plan_id) ? sm.stripe_plan_id : nil
    return false unless stripe_plan.present?

    begin
      stripe_subscription = Stripe::Subscription.create({
        customer: customer_id,
        items: [ { price: stripe_plan } ],
        expand: [ "latest_invoice.payment_intent" ]
      })

      update!(
        stripe_subscription_id: stripe_subscription.id,
        stripe_customer_id: customer_id
      )

      sync_from_stripe_subscription!(stripe_subscription)
      stripe_subscription
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to create Stripe subscription for #{name}: #{e.message}")
      errors.add(:base, "Failed to create subscription with Stripe: #{e.message}")
      false
    end
  end

  def update_stripe_subscription(plan_id, proration_behavior: "create_prorations")
    return unless stripe_subscription_id.present?

    begin
      subscription_item = current_stripe_subscription_item
      unless subscription_item
        errors.add(:base, "Stripe subscription has no subscription item to update")
        return false
      end

      item_attributes = {
        id: stripe_value(subscription_item, :id),
        price: plan_id
      }
      quantity = stripe_value(subscription_item, :quantity)
      item_attributes[:quantity] = quantity if quantity.present?

      stripe_subscription = Stripe::Subscription.update(
        stripe_subscription_id,
        items: [ item_attributes ],
        proration_behavior: proration_behavior
      )

      sync_from_stripe_subscription!(stripe_subscription)
      stripe_subscription
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to update Stripe subscription for #{name}: #{e.message}")
      errors.add(:base, "Stripe plan update failed: #{e.message}")
      false
    end
  end

  def cancel_stripe_subscription(at_period_end: false)
    return unless stripe_subscription_id.present?

    begin
      stripe_subscription = if at_period_end
        Stripe::Subscription.update(stripe_subscription_id, cancel_at_period_end: true)
      else
        Stripe::Subscription.cancel(stripe_subscription_id)
      end

      sync_from_stripe_subscription!(stripe_subscription)
      stripe_subscription
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to cancel Stripe subscription for #{name}: #{e.message}")
      errors.add(:base, "Stripe cancellation failed: #{e.message}")
      false
    end
  end

  def sync_from_stripe_subscription!(stripe_subscription)
    stripe_status_value = stripe_value(stripe_subscription, :status)
    cancel_at_period_end_value = !!stripe_value(stripe_subscription, :cancel_at_period_end)
    current_period_end_value = stripe_time(stripe_subscription, :current_period_end)
    cancel_at_value = stripe_time(stripe_subscription, :cancel_at)
    pause_collection_value = stripe_value(stripe_subscription, :pause_collection)
    subscription_item = stripe_subscription_item(stripe_subscription)

    attrs = {
      stripe_status: stripe_status_value,
      cancel_at_period_end: cancel_at_period_end_value,
      stripe_current_period_end: current_period_end_value,
      stripe_cancel_at: cancel_at_value,
      metadata: metadata_with_stripe_state(
        subscription_item_id: stripe_value(subscription_item, :id),
        pause_collection: pause_collection_value
      )
    }

    case stripe_status_value
    when "active"
      attrs[:status] = pause_collection_value.present? ? "paused" : "active"
      attrs[:auto_renew] = !cancel_at_period_end_value
      attrs[:expires_at] = current_period_end_value&.to_date if cancel_at_period_end_value
    when "trialing"
      attrs[:status] = "trial"
      attrs[:auto_renew] = !cancel_at_period_end_value
      attrs[:trial_ends_at] = current_period_end_value&.to_date if current_period_end_value.present?
    when "past_due", "unpaid", "incomplete_expired"
      attrs[:status] = "payment_failed"
      attrs[:failed_payment_alert_sent] = true
    when "canceled"
      attrs[:status] = "cancelled"
      attrs[:cancelled_at] = cancel_at_value&.to_date || Date.current
      attrs[:auto_renew] = false
      attrs[:cancel_at_period_end] = false
      attrs[:expires_at] = cancel_at_value&.to_date || Date.current
    end

    update!(attrs)
  end

  def apply_stripe_event!(stripe_subscription, event_id:, event_type:, event_created_at:)
    event_time = normalize_stripe_event_time(event_created_at)
    return false if StripeEventReceipt.exists?(event_id: event_id)

    with_lock do
      receipt = stripe_event_receipts.create!(
        event_id: event_id,
        event_type: event_type,
        event_created_at: event_time
      )

      if stripe_last_event_created_at.present? && event_time < stripe_last_event_created_at
        receipt.update!(status: "ignored_stale")
        return false
      end

      sync_from_stripe_subscription!(stripe_subscription)
      update!(
        stripe_last_event_id: event_id,
        stripe_last_event_created_at: event_time
      )
    end

    true
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
    raise unless StripeEventReceipt.exists?(event_id: event_id)

    false
  end

  def calculate_next_billing_date
    return nil unless next_billing_at.present?

    schedule.advance(next_billing_at)
  end

  # Private methods
  private

    def normalize_trial_status
      self.status = "trial" if status == "active" && trial_ends_at.present? && trial_ends_at >= Date.current
    end

    def next_billing_not_before_start
      return if started_at.blank? || next_billing_at.blank?
      return unless next_billing_at < started_at

      errors.add(:next_billing_at, "cannot be before the start date")
    end

    def calculate_trial_end_date
      # Default trial period of 7 days
      return nil unless started_at.present?
      started_at + 7.days
    end

    def billing_window_valid
      return if billing_day_start.blank? && billing_day_end.blank?

      if billing_day_start.present? ^ billing_day_end.present?
        errors.add(:base, "Both billing_day_start and billing_day_end must be set together")
        return
      end

      if billing_day_end < billing_day_start
        errors.add(:billing_day_end, "must be on or after billing_day_start")
      end
    end

    def safe_date(year, month, day)
      Date.new(year, month, [ day, Date.new(year, month, -1).day ].min)
    rescue ArgumentError
      Date.new(year, month, -1)
    end

    def stripe_value(object, key)
      if object.respond_to?(:[])
        object[key.to_s] || object[key.to_sym]
      elsif object.respond_to?(key)
        object.public_send(key)
      end
    rescue KeyError, NoMethodError
      nil
    end

    def stripe_time(object, key)
      value = stripe_value(object, key)
      value ||= stripe_value(stripe_subscription_item(object), key)
      return value if value.is_a?(Time)
      return value.to_time if value.respond_to?(:to_time) && !value.is_a?(Integer)
      return Time.zone.at(value) if value.present?

      nil
    end

    def stripe_subscription_item(object)
      items = stripe_value(object, :items)
      data = stripe_value(items, :data)
      data&.first
    end

    def current_stripe_subscription_item
      stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
      stripe_subscription_item(stripe_subscription)
    end

    def update_stripe_collection(pause_collection:)
      Stripe::Subscription.update(
        stripe_subscription_id,
        pause_collection: pause_collection
      )
    rescue Stripe::StripeError => e
      Rails.logger.error("Failed to update Stripe collection for #{name}: #{e.message}")
      errors.add(:base, "Stripe pause update failed: #{e.message}")
      false
    end

    def metadata_with_stripe_state(subscription_item_id:, pause_collection:)
      updated_metadata = (metadata || {}).deep_dup
      stripe_metadata = updated_metadata["stripe"] ||= {}

      stripe_metadata["subscription_item_id"] = subscription_item_id if subscription_item_id.present?

      if pause_collection.present?
        stripe_metadata["pause_collection"] = {
          "behavior" => stripe_value(pause_collection, :behavior),
          "resumes_at" => stripe_value(pause_collection, :resumes_at)
        }.compact
      else
        stripe_metadata.delete("pause_collection")
      end

      updated_metadata
    end

    def normalize_stripe_event_time(value)
      return value if value.is_a?(Time)
      return value.to_time if value.respond_to?(:to_time) && !value.is_a?(Integer)

      Time.zone.at(value)
    end

    def payment_date_matches_current_cycle?(paid_date)
      # Accept payments within a window around the billing date:
      # - 5 days before: to account for weekends/holidays and early charges
      # - 3 days after: grace period for late payments and bank delays.
      window_start = next_billing_at - 5.days
      window_end = next_billing_at + 3.days

      paid_date >= window_start && paid_date <= window_end
    end
end
