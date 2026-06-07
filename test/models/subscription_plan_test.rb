require "test_helper"
require "ostruct"

class SubscriptionPlanTest < ActiveSupport::TestCase
  setup do
    @subscription = subscription_plans(:netflix_subscription)
    @trial_subscription = subscription_plans(:adobe_subscription)
  end

  test "valid subscription plan" do
    assert @subscription.valid?
  end

  test "requires name" do
    @subscription.name = nil
    assert_not @subscription.valid?
    assert_includes @subscription.errors[:name], "can't be blank"
  end

  test "requires amount greater than 0" do
    @subscription.amount = 0
    assert_not @subscription.valid?
    assert_includes @subscription.errors[:amount], "must be greater than 0"
  end

  test "calculates days until renewal" do
    @subscription.next_billing_at = 10.days.from_now.to_date
    assert_equal 10, @subscription.days_until_renewal
  end

  test "calculates trial days remaining" do
    assert_equal 7, @trial_subscription.trial_days_remaining
  end

  test "monthly equivalent amount for annual billing" do
    annual_sub = @trial_subscription
    assert_equal (599.88 / 12.0), annual_sub.monthly_equivalent_amount
  end

  test "yearly equivalent amount for monthly billing" do
    assert_equal 9.99 * 12, subscription_plans(:spotify_subscription).yearly_equivalent_amount
  end

  test "active or trial returns true for active subscription" do
    assert @subscription.active_or_trial?
  end

  test "active or trial returns true for trial subscription" do
    assert @trial_subscription.active_or_trial?
  end

  test "auto renewal enabled when auto_renew is true and subscription is active" do
    @subscription.auto_renew = true
    assert @subscription.auto_renewal_enabled?
  end

  test "archive marks subscription as archived" do
    @subscription.archive!
    assert @subscription.archived
  end

  test "unarchive marks subscription as not archived" do
    @subscription.archived = true
    @subscription.unarchive!
    assert_not @subscription.archived
  end

  test "pause changes status to paused" do
    @subscription.pause!
    assert_equal "paused", @subscription.status
  end

  test "pause uses Stripe pause collection for managed subscriptions" do
    @subscription.update!(
      payment_method: "auto",
      stripe_subscription_id: "sub_test_123"
    )

    stripe_response = OpenStruct.new(
      id: "sub_test_123",
      status: "active",
      cancel_at_period_end: false,
      current_period_end: 1.month.from_now.to_i,
      cancel_at: nil,
      pause_collection: OpenStruct.new(behavior: "void"),
      items: OpenStruct.new(data: [ OpenStruct.new(id: "si_test_123") ])
    )

    Stripe::Subscription.expects(:update)
      .with("sub_test_123", pause_collection: { behavior: "void" })
      .returns(stripe_response)

    assert @subscription.pause!
    assert_equal "paused", @subscription.reload.status
    assert_equal "void", @subscription.stripe_pause_collection_behavior
  end

  test "resume changes status to active" do
    @subscription.status = "paused"
    @subscription.save!
    @subscription.resume!
    assert_equal "active", @subscription.status
  end

  test "resume clears Stripe pause collection for managed subscriptions" do
    @subscription.update!(
      status: "paused",
      payment_method: "auto",
      stripe_subscription_id: "sub_test_123",
      metadata: {
        "stripe" => {
          "pause_collection" => { "behavior" => "void" },
          "subscription_item_id" => "si_test_123"
        }
      }
    )

    stripe_response = OpenStruct.new(
      id: "sub_test_123",
      status: "active",
      cancel_at_period_end: false,
      current_period_end: 1.month.from_now.to_i,
      cancel_at: nil,
      pause_collection: nil,
      items: OpenStruct.new(data: [ OpenStruct.new(id: "si_test_123") ])
    )

    Stripe::Subscription.expects(:update)
      .with("sub_test_123", pause_collection: "")
      .returns(stripe_response)

    assert @subscription.resume!
    assert_equal "active", @subscription.reload.status
    assert_nil @subscription.stripe_pause_collection_behavior
  end

  test "cancel changes status to cancelled" do
    @subscription.cancel!
    assert_equal "cancelled", @subscription.status
    assert_not @subscription.auto_renew
  end

  test "cancel at next renewal schedules Stripe period end cancellation" do
    period_end = 1.month.from_now
    @subscription.update!(
      payment_method: "auto",
      stripe_subscription_id: "sub_test_123",
      stripe_customer_id: "cus_test_123"
    )

    stripe_response = OpenStruct.new(
      status: "active",
      cancel_at_period_end: true,
      current_period_end: period_end.to_i,
      cancel_at: nil
    )

    Stripe::Subscription.expects(:update)
      .with("sub_test_123", cancel_at_period_end: true)
      .returns(stripe_response)

    @subscription.cancel!(at_next_renewal: true)

    assert_equal "active", @subscription.reload.status
    assert @subscription.pending_cancellation?
    assert_not @subscription.auto_renew
    assert_equal period_end.to_date, @subscription.expires_at
  end

  test "cancel immediately cancels Stripe subscription and keeps audit identifiers" do
    cancel_time = Time.current
    @subscription.update!(
      payment_method: "auto",
      stripe_subscription_id: "sub_test_123",
      stripe_customer_id: "cus_test_123"
    )

    stripe_response = OpenStruct.new(
      status: "canceled",
      cancel_at_period_end: false,
      current_period_end: nil,
      cancel_at: cancel_time.to_i
    )

    Stripe::Subscription.expects(:cancel)
      .with("sub_test_123")
      .returns(stripe_response)

    @subscription.cancel!

    @subscription.reload
    assert_equal "cancelled", @subscription.status
    assert_not @subscription.cancel_at_period_end
    assert_equal "sub_test_123", @subscription.stripe_subscription_id
    assert_equal "cus_test_123", @subscription.stripe_customer_id
  end

  test "undo cancellation clears local period end cancellation" do
    @subscription.update!(
      cancel_at_period_end: true,
      auto_renew: false,
      expires_at: 1.month.from_now.to_date
    )

    assert @subscription.undo_cancellation!
    assert_not @subscription.reload.cancel_at_period_end
    assert @subscription.auto_renew
    assert_nil @subscription.expires_at
  end

  test "undo cancellation clears Stripe period end cancellation" do
    @subscription.update!(
      payment_method: "auto",
      stripe_subscription_id: "sub_test_123",
      cancel_at_period_end: true,
      auto_renew: false
    )
    stripe_response = OpenStruct.new(
      status: "active",
      cancel_at_period_end: false,
      current_period_end: 1.month.from_now.to_i,
      cancel_at: nil
    )

    Stripe::Subscription.expects(:update)
      .with("sub_test_123", cancel_at_period_end: false)
      .returns(stripe_response)

    assert @subscription.undo_cancellation!
    assert_not @subscription.reload.cancel_at_period_end
    assert @subscription.auto_renew
  end

  test "failed Stripe cancellation undo preserves pending cancellation" do
    @subscription.update!(
      payment_method: "auto",
      stripe_subscription_id: "sub_test_123",
      cancel_at_period_end: true,
      auto_renew: false
    )
    Stripe::Subscription.expects(:update)
      .with("sub_test_123", cancel_at_period_end: false)
      .raises(Stripe::InvalidRequestError.new("cannot update", "subscription"))

    assert_not @subscription.undo_cancellation!
    assert @subscription.reload.cancel_at_period_end
    assert_not @subscription.auto_renew
  end

  test "failed Stripe cancellation does not change local lifecycle" do
    @subscription.update!(
      payment_method: "auto",
      stripe_subscription_id: "sub_test_123"
    )

    Stripe::Subscription.expects(:cancel)
      .with("sub_test_123")
      .raises(Stripe::InvalidRequestError.new("cannot cancel", "subscription"))

    assert_not @subscription.cancel!
    assert_equal "active", @subscription.reload.status
    assert @subscription.auto_renew
    assert_includes @subscription.errors[:base], "Stripe cancellation failed: cannot cancel"
  end

  test "update Stripe subscription uses subscription item id" do
    @subscription.update!(
      payment_method: "auto",
      stripe_subscription_id: "sub_test_123"
    )

    current_subscription = OpenStruct.new(
      items: OpenStruct.new(data: [ OpenStruct.new(id: "si_test_123", quantity: 2) ])
    )
    updated_subscription = OpenStruct.new(
      id: "sub_test_123",
      status: "active",
      cancel_at_period_end: false,
      current_period_end: 1.month.from_now.to_i,
      cancel_at: nil,
      pause_collection: nil,
      items: OpenStruct.new(data: [ OpenStruct.new(id: "si_test_123", quantity: 2) ])
    )

    Stripe::Subscription.expects(:retrieve)
      .with("sub_test_123")
      .returns(current_subscription)
    Stripe::Subscription.expects(:update)
      .with(
        "sub_test_123",
        items: [ { id: "si_test_123", price: "price_new", quantity: 2 } ],
        proration_behavior: "create_prorations"
      )
      .returns(updated_subscription)

    assert @subscription.update_stripe_subscription("price_new")
    assert_equal "si_test_123", @subscription.reload.stripe_subscription_item_id
  end

  test "sync_from_stripe_subscription stores pending cancellation state" do
    period_end = 1.month.from_now
    stripe_subscription = OpenStruct.new(
      status: "active",
      cancel_at_period_end: true,
      current_period_end: period_end.to_i,
      cancel_at: nil
    )

    @subscription.sync_from_stripe_subscription!(stripe_subscription)

    @subscription.reload
    assert_equal "active", @subscription.status
    assert_equal "active", @subscription.stripe_status
    assert @subscription.pending_cancellation?
    assert_not @subscription.auto_renew
    assert_equal period_end.to_date, @subscription.expires_at
  end

  test "sync_from_stripe_subscription maps pause collection to paused lifecycle" do
    stripe_subscription = OpenStruct.new(
      status: "active",
      cancel_at_period_end: false,
      current_period_end: 1.month.from_now.to_i,
      cancel_at: nil,
      pause_collection: OpenStruct.new(behavior: "void"),
      items: OpenStruct.new(data: [ OpenStruct.new(id: "si_test_123") ])
    )

    @subscription.sync_from_stripe_subscription!(stripe_subscription)

    @subscription.reload
    assert_equal "paused", @subscription.status
    assert_equal "void", @subscription.stripe_pause_collection_behavior
    assert_equal "si_test_123", @subscription.stripe_subscription_item_id
  end

  test "sync_from_stripe_subscription stores canceled state" do
    cancel_time = Time.current
    stripe_subscription = OpenStruct.new(
      status: "canceled",
      cancel_at_period_end: false,
      current_period_end: nil,
      cancel_at: cancel_time.to_i
    )

    @subscription.sync_from_stripe_subscription!(stripe_subscription)

    @subscription.reload
    assert_equal "cancelled", @subscription.status
    assert_equal "canceled", @subscription.stripe_status
    assert_not @subscription.auto_renew
    assert_equal cancel_time.to_date, @subscription.cancelled_at
  end

  test "scope active returns only active subscriptions" do
    assert_includes SubscriptionPlan.active, @subscription
    assert_not_includes SubscriptionPlan.active, @trial_subscription
  end

  test "scope upcoming renewals returns subscriptions renewing within specified days" do
    @subscription.next_billing_at = 3.days.from_now.to_date
    @subscription.save!
    assert_includes SubscriptionPlan.upcoming_renewals(7), @subscription
  end

  test "status badge class returns correct class for active status" do
    assert_equal "bg-green-100 text-green-800 theme-dark:bg-green-900/20 theme-dark:text-green-200", @subscription.status_badge_class
  end

  test "status badge class returns correct class for trial status" do
    assert_equal "bg-blue-100 text-blue-800 theme-dark:bg-blue-900/20 theme-dark:text-blue-200", @trial_subscription.status_badge_class
  end

  test "record_manual_payment advances billing when payment is near billing date" do
    @subscription.update!(next_billing_at: Date.current)
    original_next = @subscription.next_billing_at

    assert_changes -> { @subscription.reload.next_billing_at } do
      @subscription.record_manual_payment!(paid_at: Date.current)
    end

    assert_equal original_next.next_month, @subscription.next_billing_at
  end

  test "record_manual_payment ignores payments far from billing date" do
    @subscription.update!(next_billing_at: Date.current + 30.days)
    original_next = @subscription.next_billing_at

    assert_no_changes -> { @subscription.reload.next_billing_at } do
      @subscription.record_manual_payment!(paid_at: Date.current)
    end

    assert_equal original_next, @subscription.next_billing_at
  end

  test "record_manual_payment accepts payments at window start" do
    billing_date = Date.current + 10.days
    @subscription.update!(next_billing_at: billing_date)

    # Window start is 5 days before next_billing_at
    paid_at = billing_date - 5.days

    assert_changes -> { @subscription.reload.next_billing_at } do
      @subscription.record_manual_payment!(paid_at: paid_at)
    end
  end

  test "record_manual_payment ignores payments when subscription is not active or trial" do
    @subscription.update!(status: "cancelled", next_billing_at: Date.current)
    original_next = @subscription.next_billing_at

    assert_no_changes -> { @subscription.reload.next_billing_at } do
      @subscription.record_manual_payment!(paid_at: Date.current)
    end

    assert_equal original_next, @subscription.next_billing_at
  end

  test "record_manual_payment accepts late payments within grace period" do
    billing_date = Date.current - 2.days
    @subscription.update!(next_billing_at: billing_date)

    # Payment 2 days after billing (within 3-day grace)
    result = @subscription.record_manual_payment!(paid_at: Date.current)

    assert result, "Should return true when billing is advanced"
    assert_equal billing_date.next_month, @subscription.reload.next_billing_at
  end

  test "record_manual_payment rejects payments after grace period" do
    billing_date = Date.current - 5.days
    @subscription.update!(next_billing_at: billing_date)
    original_next = @subscription.next_billing_at

    # Payment 5 days after billing (outside 3-day grace)
    result = @subscription.record_manual_payment!(paid_at: Date.current)

    assert_not result, "Should return false when billing is NOT advanced"
    assert_equal original_next, @subscription.reload.next_billing_at
  end

  test "record_manual_payment returns boolean indicating success" do
    @subscription.update!(next_billing_at: Date.current)

    result = @subscription.record_manual_payment!(paid_at: Date.current)
    assert_equal true, result

    # Second call should fail (billing already advanced)
    result_second = @subscription.record_manual_payment!(paid_at: Date.current)
    assert_equal false, result_second
  end

  test "record_payment_entry creates renewal and advances billing" do
    @subscription.subscription_renewals.destroy_all
    @subscription.update!(next_billing_at: Date.current)

    entry = @subscription.account.entries.create!(
      name: "Netflix payment",
      date: Date.current,
      amount: @subscription.amount,
      currency: @subscription.currency,
      entryable: Transaction.new(
        kind: "standard",
        category: categories(:food_and_drink),
        merchant: merchants(:netflix)
      )
    )

    assert_difference -> { @subscription.subscription_renewals.count } => 1 do
      assert @subscription.record_payment_entry!(entry)
    end

    renewal = @subscription.subscription_renewals.last
    assert_equal entry, renewal.entry
    assert_equal "paid", renewal.status
    assert_equal Date.current.next_month, @subscription.reload.next_billing_at
  end

  test "record_payment_entry does not create duplicate renewal for same entry" do
    @subscription.subscription_renewals.destroy_all
    @subscription.update!(next_billing_at: Date.current)

    entry = @subscription.account.entries.create!(
      name: "Netflix payment",
      date: Date.current,
      amount: @subscription.amount,
      currency: @subscription.currency,
      entryable: Transaction.new(
        kind: "standard",
        category: categories(:food_and_drink),
        merchant: merchants(:netflix)
      )
    )

    assert @subscription.record_payment_entry!(entry)

    assert_no_difference -> { @subscription.subscription_renewals.count } do
      assert_not @subscription.record_payment_entry!(entry)
    end
  end

  test "one-time payment completes the subscription instead of advancing" do
    @subscription.update!(
      next_billing_at: Date.current,
      billing_cycle: "one_time",
      metadata: { "schedule" => { "count" => 1, "unit" => "once" } }
    )

    @subscription.mark_as_renewed!(Date.current)

    assert @subscription.reload.expired?
    assert_not @subscription.auto_renew
    assert_equal Date.current, @subscription.expires_at
  end

  test "future trial date normalizes a new active subscription to trial" do
    subscription = @subscription.dup
    subscription.name = "Trial normalization"
    subscription.trial_ends_at = 2.days.from_now.to_date
    subscription.status = "active"

    assert subscription.valid?
    assert_equal "trial", subscription.status
  end

  test "next billing date cannot precede the start date" do
    @subscription.started_at = Date.current
    @subscription.next_billing_at = Date.yesterday

    assert_not @subscription.valid?
    assert_includes @subscription.errors[:next_billing_at], "cannot be before the start date"
  end

  test "one-time subscription does not present a monthly equivalent" do
    @subscription.metadata = { "schedule" => { "count" => 1, "unit" => "once" } }
    @subscription.billing_cycle = "one_time"

    assert_equal "Not recurring", @subscription.formatted_monthly_amount
  end
end
