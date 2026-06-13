require "test_helper"

class SubscriptionPlan::RenewalFormTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    Current.session = @user.sessions.create!
    @subscription_plan = subscription_plans(:netflix_subscription)
    @account = accounts(:depository)
    @category = categories(:food_and_drink)
  end

  test "valid with correct attributes" do
    form = SubscriptionPlan::RenewalForm.new(
      subscription_plan: @subscription_plan,
      account_id: @account.id,
      actual_amount: 22.99,
      admin_fee: 1.50,
      paid_at: Date.current,
      currency: "USD",
      category_id: @category.id
    )
    assert form.valid?
  end

  test "invalid with missing subscription_plan" do
    form = SubscriptionPlan::RenewalForm.new(
      account_id: @account.id,
      actual_amount: 22.99,
      paid_at: Date.current,
      category_id: @category.id
    )
    assert_not form.valid?
    assert_includes form.errors[:subscription_plan], "can't be blank"
  end

  test "invalid with missing account_id" do
    form = SubscriptionPlan::RenewalForm.new(
      subscription_plan: @subscription_plan,
      actual_amount: 22.99,
      paid_at: Date.current,
      category_id: @category.id
    )
    assert_not form.valid?
    assert_includes form.errors[:account_id], "can't be blank"
  end

  test "invalid with non-positive actual_amount" do
    form = SubscriptionPlan::RenewalForm.new(
      subscription_plan: @subscription_plan,
      account_id: @account.id,
      actual_amount: 0,
      paid_at: Date.current,
      category_id: @category.id
    )
    assert_not form.valid?
    assert_includes form.errors[:actual_amount], "must be greater than 0"
  end

  test "invalid with negative admin_fee" do
    form = SubscriptionPlan::RenewalForm.new(
      subscription_plan: @subscription_plan,
      account_id: @account.id,
      actual_amount: 22.99,
      admin_fee: -1,
      paid_at: Date.current,
      category_id: @category.id
    )
    assert_not form.valid?
    assert_includes form.errors[:admin_fee], "must be greater than or equal to 0"
  end

  test "invalid with missing category_id when no default available" do
    # Temporarily remove all family categories to force no default
    Current.family.categories.destroy_all
    form = SubscriptionPlan::RenewalForm.new(
      subscription_plan: @subscription_plan,
      account_id: @account.id,
      actual_amount: 22.99,
      paid_at: Date.current
    )
    assert_not form.valid?
    assert_includes form.errors[:category_id], "can't be blank"
  end

  test "invalid with category from another family" do
    form = SubscriptionPlan::RenewalForm.new(
      subscription_plan: @subscription_plan,
      account_id: @account.id,
      actual_amount: 22.99,
      paid_at: Date.current,
      category_id: categories(:one).id
    )

    assert_not form.valid?
    assert_includes form.errors[:category_id], "is invalid"
  end

  test "creates entry, transaction, renewal, advances billing, and updates default account when true" do
    new_account = accounts(:credit_card)
    form = SubscriptionPlan::RenewalForm.new(
      subscription_plan: @subscription_plan,
      account_id: new_account.id,
      actual_amount: 22.99,
      admin_fee: 1.50,
      paid_at: Date.current,
      currency: "USD",
      category_id: @category.id,
      update_default_account: true,
      notes: "Payment recorded via test"
    )

    original_next_billing_at = @subscription_plan.next_billing_at
    expected_next_billing_at = @subscription_plan.calculate_next_billing_date

    assert_difference -> { @subscription_plan.subscription_renewals.count } => 1, -> { Entry.count } => 1 do
      renewal = form.create
      assert_not_nil renewal
      assert_equal "paid", renewal.status
      assert_equal new_account.id, renewal.account_id
      assert_equal 22.99, renewal.actual_amount
      assert_equal 1.50, renewal.admin_fee
    end

    @subscription_plan.reload
    assert_equal new_account.id, @subscription_plan.account_id
    assert_equal expected_next_billing_at, @subscription_plan.next_billing_at

    # Verify positive amount is stored for expense (debit/outflow on asset account)
    entry = @subscription_plan.subscription_renewals.paid.order(paid_at: :desc).first.entry
    assert_equal 24.49, entry.amount # 22.99 actual_amount + 1.50 admin_fee
    assert_equal @category.id, entry.entryable.category_id
  end

  test "does not update default account if update_default_account is false" do
    original_account_id = @subscription_plan.account_id
    new_account = accounts(:credit_card)

    form = SubscriptionPlan::RenewalForm.new(
      subscription_plan: @subscription_plan,
      account_id: new_account.id,
      actual_amount: 22.99,
      paid_at: Date.current,
      currency: "USD",
      category_id: @category.id,
      update_default_account: false
    )

    assert_not_nil form.create

    @subscription_plan.reload
    assert_equal original_account_id, @subscription_plan.account_id
  end

  test "creates renewal without Current family context" do
    Current.reset
    @subscription_plan.subscription_renewals.destroy_all

    form = SubscriptionPlan::RenewalForm.new(
      subscription_plan: @subscription_plan,
      account_id: @account.id,
      actual_amount: 22.99,
      paid_at: Date.current,
      currency: "USD"
    )

    assert_difference -> { @subscription_plan.subscription_renewals.count } => 1, -> { Entry.count } => 1 do
      assert_not_nil form.create
    end

    renewal = @subscription_plan.subscription_renewals.last
    assert_equal @account, renewal.account
    assert_equal @subscription_plan.family, renewal.account.family
  end
end
