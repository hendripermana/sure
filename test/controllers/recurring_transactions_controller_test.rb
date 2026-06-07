require "test_helper"

class RecurringTransactionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @family = families(:dylan_family)
    @family.recurring_transactions.destroy_all
    RecurringTransactionSuppression.where(family: @family).delete_all
  end

  test "index hides ignored recurring transactions" do
    visible = @family.recurring_transactions.create!(
      name: "Visible Gym",
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: 5.days.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )

    ignored = @family.recurring_transactions.create!(
      name: "Ignored Gym",
      amount: 55.99,
      currency: "USD",
      expected_day_of_month: 10,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: 10.days.from_now.to_date,
      status: "ignored",
      occurrence_count: 3
    )

    get recurring_transactions_url

    assert_response :success
    assert_includes response.body, visible.name
    assert_not_includes response.body, ignored.name
  end

  test "index separates detected transactions from recurring transfers" do
    detected = @family.recurring_transactions.create!(
      name: "Detected Membership",
      account: accounts(:depository),
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: 5.days.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )
    transfer = @family.recurring_transactions.create!(
      name: "Monthly Investment",
      account: accounts(:depository),
      destination_account: accounts(:investment),
      amount: 100,
      currency: "USD",
      expected_day_of_month: 10,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: 10.days.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )

    get recurring_transactions_url
    assert_includes response.body, detected.name
    assert_not_includes response.body, transfer.name

    get recurring_transactions_url(kind: "transfers")
    assert_not_includes response.body, detected.name
    assert_includes response.body, transfer.name
  end

  test "ignored view restores recurring transaction and removes suppression" do
    recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      account: accounts(:depository),
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: 5.days.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )
    recurring.ignore!

    get recurring_transactions_url(kind: "ignored")
    assert_response :success
    assert_includes response.body, recurring.merchant.name

    assert_difference "RecurringTransactionSuppression.count", -1 do
      post restore_recurring_transaction_url(recurring)
    end

    assert_redirected_to recurring_transactions_url(kind: "ignored")
    assert recurring.reload.active?
  end

  test "confirm marks the pattern as reviewed" do
    recurring = @family.recurring_transactions.create!(
      name: "Confirmed Membership",
      account: accounts(:depository),
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: 5.days.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )

    post confirm_recurring_transaction_url(recurring)

    assert_redirected_to recurring_transactions_url
    assert recurring.reload.manual?
    assert recurring.audit_logs.where(event: "recurring.confirmed").exists?
  end

  test "mark transfer validates and assigns a family destination account" do
    recurring = @family.recurring_transactions.create!(
      name: "Monthly Savings",
      account: accounts(:depository),
      amount: 200,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: 5.days.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )

    post mark_transfer_recurring_transaction_url(recurring),
      params: { destination_account_id: accounts(:investment).id }

    assert_redirected_to recurring_transactions_url(kind: "transfers")
    assert_equal accounts(:investment), recurring.reload.destination_account
    assert recurring.audit_logs.where(event: "recurring.classified_transfer").exists?
  end

  test "destroy suppresses recurring transaction without deleting it" do
    recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: 5.days.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )

    assert_no_difference "RecurringTransaction.count" do
      delete recurring_transaction_url(recurring)
    end

    assert_redirected_to recurring_transactions_url
    assert_equal "ignored", recurring.reload.status
  end

  test "create_subscription promotes recurring transaction to subscription plan" do
    recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: 5.days.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )

    assert_difference "SubscriptionPlan.count", 1 do
      post create_subscription_recurring_transaction_url(recurring)
    end

    subscription_plan = SubscriptionPlan.order(:created_at).last
    assert_redirected_to subscription_plan_url(subscription_plan)
    assert_equal "ignored", recurring.reload.status
    assert_equal recurring.id, subscription_plan.metadata.dig("source", "id")
  end
end
