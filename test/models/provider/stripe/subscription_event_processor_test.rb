require "test_helper"
require "ostruct"

class Provider::Stripe::SubscriptionEventProcessorTest < ActiveSupport::TestCase
  test "handles subscription event" do
    test_customer_id = "test-customer-id"
    test_subscription_id = "test-subscription-id"

    mock_event = JSON.parse({
      type: "customer.subscription.created",
      data: {
        object: {
          id: test_subscription_id,
          status: "active",
          customer: test_customer_id,
          items: {
            data: [
              {
                current_period_end: 1.month.from_now.to_i,
                plan: {
                  interval: "month",
                  amount: 900,
                  currency: "usd"
                }
              }
            ]
          }
        }
      }
    }.to_json, object_class: OpenStruct)

    family = Family.create!(
      name: "Test Subscribed Family",
      stripe_customer_id: test_customer_id
    )

    family.start_subscription!(test_subscription_id)

    processor = Provider::Stripe::SubscriptionEventProcessor.new(mock_event)

    assert_equal "active", family.subscription.status
    assert_equal test_subscription_id, family.subscription.stripe_id
    assert_nil family.subscription.amount
    assert_nil family.subscription.currency
    assert_nil family.subscription.current_period_ends_at

    processor.process

    family.reload

    assert_equal "active", family.subscription.status
    assert_equal test_subscription_id, family.subscription.stripe_id
    assert_equal 9, family.subscription.amount
    assert_equal "USD", family.subscription.currency
    assert family.subscription.current_period_ends_at > 20.days.from_now
  end

  test "syncs matching subscription plan before app billing subscription" do
    test_subscription_id = "sub-plan-test-id"
    period_end = 1.month.from_now
    subscription_plan = subscription_plans(:netflix_subscription)
    subscription_plan.update!(
      payment_method: "auto",
      stripe_subscription_id: test_subscription_id
    )

    mock_event = JSON.parse({
      type: "customer.subscription.updated",
      data: {
        object: {
          id: test_subscription_id,
          status: "active",
          customer: "unrelated-customer-id",
          cancel_at_period_end: true,
          current_period_end: period_end.to_i,
          items: {
            data: [
              {
                current_period_end: period_end.to_i,
                plan: {
                  interval: "month",
                  amount: 2299,
                  currency: "usd"
                }
              }
            ]
          }
        }
      }
    }.to_json, object_class: OpenStruct)

    Provider::Stripe::SubscriptionEventProcessor.new(mock_event).process

    subscription_plan.reload
    assert_equal "active", subscription_plan.stripe_status
    assert subscription_plan.pending_cancellation?
    assert_equal period_end.to_date, subscription_plan.expires_at
  end

  test "syncs Stripe pause collection into subscription plan lifecycle" do
    test_subscription_id = "sub-paused-plan-id"
    subscription_plan = subscription_plans(:netflix_subscription)
    subscription_plan.update!(
      payment_method: "auto",
      stripe_subscription_id: test_subscription_id
    )

    mock_event = JSON.parse({
      type: "customer.subscription.updated",
      data: {
        object: {
          id: test_subscription_id,
          status: "active",
          customer: "unrelated-customer-id",
          cancel_at_period_end: false,
          pause_collection: { behavior: "void" },
          items: {
            data: [
              {
                id: "si_paused_plan",
                current_period_end: 1.month.from_now.to_i,
                plan: {
                  interval: "month",
                  amount: 2299,
                  currency: "usd"
                }
              }
            ]
          }
        }
      }
    }.to_json, object_class: OpenStruct)

    Provider::Stripe::SubscriptionEventProcessor.new(mock_event).process

    subscription_plan.reload
    assert_equal "paused", subscription_plan.status
    assert_equal "void", subscription_plan.stripe_pause_collection_behavior
    assert_equal "si_paused_plan", subscription_plan.stripe_subscription_item_id
  end

  test "ignores duplicate Stripe event delivery" do
    subscription_plan = subscription_plans(:netflix_subscription)
    subscription_plan.update!(payment_method: "auto", stripe_subscription_id: "sub_idempotent")
    subscription = stripe_subscription_object(id: "sub_idempotent", status: "active")
    event = stripe_event(id: "evt_duplicate", created: 1_750_000_000, subscription: subscription)

    Provider::Stripe::SubscriptionEventProcessor.new(event).process
    subscription.status = "canceled"
    Provider::Stripe::SubscriptionEventProcessor.new(event).process

    assert_equal "active", subscription_plan.reload.status
    assert_equal 1, StripeEventReceipt.where(event_id: "evt_duplicate").count
  end

  test "ignores Stripe events older than the last applied event" do
    subscription_plan = subscription_plans(:netflix_subscription)
    subscription_plan.update!(payment_method: "auto", stripe_subscription_id: "sub_ordered")

    newer_event = stripe_event(
      id: "evt_newer",
      created: 1_750_000_100,
      subscription: stripe_subscription_object(id: "sub_ordered", status: "active")
    )
    stale_event = stripe_event(
      id: "evt_stale",
      created: 1_750_000_000,
      subscription: stripe_subscription_object(id: "sub_ordered", status: "canceled")
    )

    Provider::Stripe::SubscriptionEventProcessor.new(newer_event).process
    Provider::Stripe::SubscriptionEventProcessor.new(stale_event).process

    subscription_plan.reload
    assert_equal "active", subscription_plan.status
    assert_equal "evt_newer", subscription_plan.stripe_last_event_id
    assert_equal "ignored_stale", StripeEventReceipt.find_by!(event_id: "evt_stale").status
  end

  private
    def stripe_event(id:, created:, subscription:)
      OpenStruct.new(
        id: id,
        type: "customer.subscription.updated",
        created: created,
        data: OpenStruct.new(object: subscription)
      )
    end

    def stripe_subscription_object(id:, status:)
      OpenStruct.new(
        id: id,
        status: status,
        customer: "cus_test",
        cancel_at_period_end: false,
        current_period_end: 1.month.from_now.to_i,
        cancel_at: status == "canceled" ? Time.current.to_i : nil,
        pause_collection: nil,
        items: OpenStruct.new(data: [ OpenStruct.new(id: "si_test") ])
      )
    end
end
