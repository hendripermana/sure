require "test_helper"

class SubscriptionRenewalJobTest < ActiveJob::TestCase
  setup do
    @subscription_plan = subscription_plans(:netflix_subscription)
    @subscription_plan.subscription_renewals.destroy_all
    @job = SubscriptionRenewalJob.new
  end

  test "creates stripe renewal through entry transaction pipeline" do
    invoice = Struct.new(:id).new("in_test_123")
    stripe_subscription = Struct.new(:latest_invoice).new(invoice)
    billing_period_start = @subscription_plan.next_billing_at
    billing_period_end = @subscription_plan.calculate_next_billing_date

    assert_difference -> { Entry.count } => 1, -> { Transaction.count } => 1, -> { @subscription_plan.subscription_renewals.count } => 1 do
      @job.send(
        :create_stripe_transaction,
        @subscription_plan,
        stripe_subscription,
        billing_period_start: billing_period_start,
        billing_period_end: billing_period_end
      )
    end

    renewal = @subscription_plan.subscription_renewals.last
    entry = renewal.entry

    assert_equal @subscription_plan.account, entry.account
    assert_equal "Subscription: #{@subscription_plan.name}", entry.name
    assert_equal @subscription_plan.amount, entry.amount
    assert_equal @subscription_plan.currency, entry.currency
    assert_equal "paid", renewal.status
    assert_equal billing_period_start, renewal.billing_period_start
    assert_equal billing_period_end, renewal.billing_period_end
    assert_equal "in_test_123", entry.entryable.extra["stripe_invoice_id"]
  end

  test "processes manual renewal without Current family context" do
    Current.reset
    subscription = subscription_plans(:spotify_subscription)
    subscription.subscription_renewals.destroy_all
    renewal_date = subscription.next_billing_at

    assert_difference -> { Entry.count } => 1, -> { Transaction.count } => 1, -> { subscription.subscription_renewals.count } => 1 do
      @job.send(:process_subscription_renewal, subscription, renewal_date)
    end

    renewal = subscription.subscription_renewals.last
    assert_equal "paid", renewal.status
    assert_equal renewal_date, renewal.paid_at
    assert_equal renewal_date.next_month, subscription.reload.next_billing_at
  end
end
