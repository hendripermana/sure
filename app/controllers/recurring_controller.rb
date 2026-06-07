class RecurringController < ApplicationController
  def index
    subscriptions = Current.family.subscription_plans.unarchived
    recurring_transactions = Current.family.recurring_transactions

    @active_subscriptions = subscriptions.active
    @monthly_commitment = @active_subscriptions.sum(&:monthly_equivalent_amount)
    @detected_count = recurring_transactions.visible.where(destination_account_id: nil).count
    @transfer_count = recurring_transactions.visible.where.not(destination_account_id: nil).count
    @ignored_count = recurring_transactions.ignored.count
    @upcoming_subscriptions = @active_subscriptions
      .where.not(next_billing_at: nil)
      .order(:next_billing_at)
      .limit(5)
    @upcoming_patterns = recurring_transactions
      .visible
      .active
      .where.not(next_expected_date: nil)
      .order(:next_expected_date)
      .limit(5)
    @forecast = Recurring::Forecast.new(Current.family)
    @forecast_items = @forecast.projected_items.first(12)
    auditable_ids = subscriptions.pluck(:id) + recurring_transactions.pluck(:id)
    @recent_events = AuditLog
      .recurring_events
      .where(auditable_type: %w[SubscriptionPlan RecurringTransaction], auditable_id: auditable_ids)
      .preload(:auditable)
      .reverse_chronological
      .limit(10)
  end
end
