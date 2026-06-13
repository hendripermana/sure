require "test_helper"

class SubscriptionRenewalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    sign_in @user
    @subscription_plan = subscription_plans(:netflix_subscription)
    @account = accounts(:depository)
    @category = categories(:food_and_drink)
  end

  test "should get index" do
    get subscription_plan_subscription_renewals_url(@subscription_plan)
    assert_response :success
  end

  test "should get new" do
    get new_subscription_plan_subscription_renewal_url(@subscription_plan)
    assert_response :success
  end

  test "should reject recording a payment for a paused subscription" do
    @subscription_plan.update!(status: "paused")

    get new_subscription_plan_subscription_renewal_url(@subscription_plan)

    assert_redirected_to subscription_plan_path(@subscription_plan)
    assert_equal "Payments can only be recorded for active or trial subscriptions.", flash[:alert]
  end

  test "should create subscription renewal via HTML redirect" do
    assert_difference -> { @subscription_plan.subscription_renewals.count } => 1, -> { Entry.count } => 1 do
      post subscription_plan_subscription_renewals_url(@subscription_plan), params: {
        subscription_plan_renewal_form: {
          account_id: @account.id,
          actual_amount: 22.99,
          admin_fee: 0,
          paid_at: Date.current,
          update_default_account: "0",
          category_id: @category.id
        }
      }
    end
    assert_redirected_to subscription_plans_path
    assert_equal "Payment recorded successfully!", flash[:notice]
  end

  test "should create subscription renewal via Turbo Stream" do
    assert_difference -> { @subscription_plan.subscription_renewals.count } => 1, -> { Entry.count } => 1 do
      post subscription_plan_subscription_renewals_url(@subscription_plan), as: :turbo_stream, params: {
        subscription_plan_renewal_form: {
          account_id: @account.id,
          actual_amount: 22.99,
          admin_fee: 0,
          paid_at: Date.current,
          update_default_account: "0",
          category_id: @category.id
        }
      }
    end
    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
  end

  test "should not create with invalid params" do
    assert_no_difference -> { @subscription_plan.subscription_renewals.count } do
      post subscription_plan_subscription_renewals_url(@subscription_plan), params: {
        subscription_plan_renewal_form: {
          account_id: @account.id,
          actual_amount: 0, # invalid
          paid_at: Date.current,
          category_id: @category.id
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "should not create with category from another family" do
    assert_no_difference -> { @subscription_plan.subscription_renewals.count } do
      post subscription_plan_subscription_renewals_url(@subscription_plan), params: {
        subscription_plan_renewal_form: {
          account_id: @account.id,
          actual_amount: 22.99,
          paid_at: Date.current,
          category_id: categories(:one).id
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
