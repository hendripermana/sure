require "test_helper"

class SubscriptionPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @subscription_plan = subscription_plans(:netflix_subscription)
  end

  test "should get index" do
    get subscription_plans_url
    assert_response :success
    assert_select "a[href='#{new_subscription_plan_path}'].bg-primary.text-on-primary", text: /Add Subscription/
  end

  test "index edit action uses full page navigation" do
    get subscription_plans_url

    assert_response :success
    assert_select "a[href='#{edit_subscription_plan_path(@subscription_plan)}']", minimum: 1
    assert_select "a[href='#{edit_subscription_plan_path(@subscription_plan)}'][data-turbo-frame='modal']", count: 0
  end

  test "index renders destructive menu confirmation for cancelled subscriptions" do
    @subscription_plan.update!(status: "cancelled")

    get subscription_plans_url
    assert_response :success

    row_id = ActionView::RecordIdentifier.dom_id(@subscription_plan, :row)
    assert_select "tr##{row_id}" do
      assert_select "[data-subscription-status='cancelled']", text: /Cancelled/
      assert_select "[data-subscription-billing-state]", text: /Ended/
    end
    assert_select "[data-turbo-confirm='Are you sure you want to delete this subscription?']"
  end

  test "index renders paused lifecycle separately from billing state" do
    @subscription_plan.update!(status: "paused")

    get subscription_plans_url
    assert_response :success

    row_id = ActionView::RecordIdentifier.dom_id(@subscription_plan, :row)
    assert_select "tr##{row_id}" do
      assert_select "[data-subscription-status='paused']", text: /Paused/
      assert_select "[data-subscription-billing-state]", text: /Renewal paused/
    end
  end

  test "should get show" do
    get subscription_plan_url(@subscription_plan)
    assert_response :success
  end

  test "show exposes record payment for active subscriptions" do
    get subscription_plan_url(@subscription_plan)

    assert_response :success
    assert_select "a[href='#{new_subscription_plan_subscription_renewal_path(@subscription_plan)}'][data-turbo-frame='modal']", text: /Record Payment/
  end

  test "show hides record payment for paused subscriptions" do
    @subscription_plan.update!(status: "paused")

    get subscription_plan_url(@subscription_plan)

    assert_response :success
    assert_select "a[href='#{new_subscription_plan_subscription_renewal_path(@subscription_plan)}']", count: 0
    assert_select "p", text: /matching charge.*unexpected renewal/i
  end

  test "show renders turbo patch lifecycle actions" do
    get subscription_plan_url(@subscription_plan)
    assert_response :success

    assert_select "a[href='#{pause_subscription_plan_path(@subscription_plan)}'][data-turbo-method='patch']", text: /Pause/
    assert_select "form[action='#{cancel_subscription_plan_path(@subscription_plan, timing: "period_end")}']" do
      assert_select "button[data-turbo-confirm]", text: /Cancel at renewal/
    end
    assert_select "form[action='#{cancel_subscription_plan_path(@subscription_plan, timing: "immediate")}']" do
      assert_select "button[data-turbo-confirm]", text: /Cancel now/
    end
    assert_select "a[data-method='patch']", count: 0
  end

  test "show renders turbo patch resume action when paused" do
    @subscription_plan.update!(status: "paused")

    get subscription_plan_url(@subscription_plan)
    assert_response :success

    assert_select "a[href='#{resume_subscription_plan_path(@subscription_plan)}'][data-turbo-method='patch']", text: /Resume/
    assert_select "a[data-method='patch']", count: 0
  end

  test "should get new" do
    get new_subscription_plan_url
    assert_response :success
    assert_select "[data-controller~='subscription-schedule']"
    assert_select "[data-subscription-schedule-target='count']"
    assert_select "[data-subscription-schedule-target='unit']"
    assert_select "[data-subscription-schedule-target='start']"
    assert_select "[data-subscription-schedule-target='next']"
  end

  test "should get edit" do
    get edit_subscription_plan_url(@subscription_plan)
    assert_response :success
  end

  test "should create subscription plan" do
    # Create a new service for the test to avoid unique constraint violation
    new_service = Service.create!(
      name: "Test Service #{SecureRandom.hex(4)}",
      category: "software",
      billing_frequency: "monthly"
    )

    assert_difference("SubscriptionPlan.count") do
      post subscription_plans_url, params: {
        subscription_plan: {
          name: "New Subscription",
          service_id: new_service.id,
          account_id: accounts(:depository).id,
          amount: 19.99,
          currency: "USD",
          billing_cycle: "monthly",
          status: "active",
          payment_method: "manual",
          started_at: Date.current,
          next_billing_at: 1.month.from_now.to_date,
          auto_renew: true
        }
      }
    end
    assert_redirected_to subscription_plans_url
  end

  test "should update subscription plan" do
    patch subscription_plan_url(@subscription_plan), params: {
      subscription_plan: { name: "Updated Netflix" }
    }
    assert_redirected_to subscription_plans_url
    @subscription_plan.reload
    assert_equal "Updated Netflix", @subscription_plan.name
  end

  test "updates a flexible billing schedule" do
    patch subscription_plan_url(@subscription_plan), params: {
      subscription_plan: {
        interval_count: 2,
        interval_unit: "week"
      }
    }

    assert_redirected_to subscription_plans_url
    @subscription_plan.reload
    assert_equal({ "count" => 2, "unit" => "week" }, @subscription_plan.metadata["schedule"])
    assert_equal "Every 2 weeks", @subscription_plan.formatted_billing_cycle
  end

  test "should archive subscription plan on destroy" do
    delete subscription_plan_url(@subscription_plan)
    assert_redirected_to subscription_plans_url
    @subscription_plan.reload
    assert @subscription_plan.archived
  end

  test "should pause subscription plan" do
    patch pause_subscription_plan_url(@subscription_plan)
    assert_redirected_to subscription_plans_url
    @subscription_plan.reload
    assert_equal "paused", @subscription_plan.status
  end

  test "should resume subscription plan" do
    @subscription_plan.update!(status: "paused")
    patch resume_subscription_plan_url(@subscription_plan)
    assert_redirected_to subscription_plans_url
    @subscription_plan.reload
    assert_equal "active", @subscription_plan.status
  end

  test "should cancel subscription plan" do
    patch cancel_subscription_plan_url(@subscription_plan)
    assert_redirected_to subscription_plans_url
    @subscription_plan.reload
    assert_equal "cancelled", @subscription_plan.status
  end

  test "should schedule cancellation at next renewal" do
    patch cancel_subscription_plan_url(@subscription_plan), params: { timing: "period_end" }

    assert_redirected_to subscription_plans_url
    @subscription_plan.reload
    assert_equal "active", @subscription_plan.status
    assert @subscription_plan.pending_cancellation?
    assert_not @subscription_plan.auto_renew
  end

  test "index exposes immediate and period end cancellation choices" do
    get subscription_plans_url

    assert_response :success
    assert_select "form[action='#{cancel_subscription_plan_path(@subscription_plan, timing: "period_end")}']" do
      assert_select "button", text: /Cancel at renewal/
    end
    assert_select "form[action='#{cancel_subscription_plan_path(@subscription_plan, timing: "immediate")}']" do
      assert_select "button", text: /Cancel now/
    end
  end

  test "undoes scheduled cancellation" do
    @subscription_plan.update!(cancel_at_period_end: true, auto_renew: false)

    patch undo_cancellation_subscription_plan_url(@subscription_plan)

    assert_redirected_to subscription_plans_url
    assert_not @subscription_plan.reload.cancel_at_period_end
    assert @subscription_plan.auto_renew
  end

  test "index exposes keep subscription for pending cancellation" do
    @subscription_plan.update!(cancel_at_period_end: true, auto_renew: false)

    get subscription_plans_url

    assert_response :success
    assert_select "form[action='#{undo_cancellation_subscription_plan_path(@subscription_plan)}']" do
      assert_select "button", text: /Keep subscription/
    end
  end
end
