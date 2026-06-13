class SubscriptionRenewal < ApplicationRecord
  include Monetizable

  belongs_to :subscription_plan
  belongs_to :account
  belongs_to :entry, optional: true

  monetize :template_amount, :actual_amount, :admin_fee, :total_paid

  STATUSES = %w[pending paid skipped failed refunded].freeze

  validates :cycle_number, presence: true, numericality: { greater_than: 0 }
  validates :billing_period_start, presence: true
  validates :billing_period_end, presence: true
  validates :template_amount, presence: true, numericality: { greater_than: 0 }
  validates :actual_amount, presence: true, numericality: { greater_than: 0 }
  validates :admin_fee, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :currency, presence: true, length: { is: 3 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :cycle_number, uniqueness: { scope: :subscription_plan_id }
  validate :billing_period_valid
  validate :paid_at_required_when_paid

  scope :paid, -> { where(status: "paid") }
  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }
  scope :for_plan, ->(plan) { where(subscription_plan: plan) }
  scope :chronological, -> { order(billing_period_start: :asc) }
  scope :reverse_chronological, -> { order(billing_period_start: :desc) }

  # Mark this renewal as paid and link the transaction entry
  def mark_paid!(paid_at:, actual_amount: nil, admin_fee: nil, account_id: nil, entry_id: nil, notes: nil, payment_method: nil)
    attrs = {
      status: "paid",
      paid_at: paid_at
    }
    attrs[:actual_amount] = actual_amount if actual_amount.present?
    attrs[:admin_fee] = admin_fee if admin_fee.present?
    attrs[:account_id] = account_id if account_id.present?
    attrs[:entry_id] = entry_id if entry_id.present?
    attrs[:notes] = notes if notes.present?
    attrs[:payment_method] = payment_method if payment_method.present?

    update!(attrs)
  end

  def mark_failed!(notes: nil)
    update!(status: "failed", notes: notes)
  end

  def mark_skipped!(notes: nil)
    update!(status: "skipped", notes: notes)
  end

  def paid?
    status == "paid"
  end

  def overdue?
    status == "pending" && billing_period_end < Date.current
  end

  def within_payment_window?
    return false unless status == "pending"

    Date.current.between?(billing_period_start, billing_period_end)
  end

  # Did the user override the default payment account?
  def account_overridden?
    account_id != subscription_plan.account_id
  end

  # Did the actual amount differ from the template?
  def amount_differs?
    actual_amount != template_amount
  end

  private

    def billing_period_valid
      return if billing_period_start.blank? || billing_period_end.blank?

      if billing_period_end < billing_period_start
        errors.add(:billing_period_end, "must be on or after billing period start")
      end
    end

    def paid_at_required_when_paid
      return unless status == "paid"
      return if paid_at.present?

      errors.add(:paid_at, "is required when status is paid")
    end

    def monetizable_currency
      currency
    end
end
