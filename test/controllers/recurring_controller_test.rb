require "test_helper"

class RecurringControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "shows the recurring workspace overview" do
    get recurring_url

    assert_response :success
    assert_select "h1", text: "Recurring"
    assert_select "a[href='#{subscription_plans_path}']", text: /Subscriptions/
    assert_select "a[href='#{recurring_transactions_path}']", text: /Detected/
    assert_select "a[href='#{recurring_transactions_path(kind: "transfers")}']", text: /Transfers/
    assert_select "a[href='#{recurring_transactions_path(kind: "ignored")}']", text: /Ignored/
  end

  test "attention feed identifies the commitment and reconciliation context" do
    subscription = subscription_plans(:netflix_subscription)
    Recurring::EventRecorder.record!(
      record: subscription,
      event: "recurring.amount_changed",
      key: "overview-context-test",
      title: "Amount changed",
      detail: "Expected 22.99, observed 27.99.",
      severity: "warning",
      metadata: {
        expected_date: Date.current,
        expected_amount: 22.99,
        observed_amount: 27.99,
        entry_count: 1
      }
    )

    get recurring_url

    assert_response :success
    assert_select "[data-recurring-event]", text: /Amount changed.*Netflix Premium/m
    assert_select "[data-recurring-event]", text: /Expected.*USD 22\.99/m
    assert_select "[data-recurring-event]", text: /Observed.*USD 27\.99/m
  end
end
