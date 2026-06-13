require "test_helper"

class RecurringTransactionTest < ActiveSupport::TestCase
  def setup
    @family = families(:dylan_family)
    @merchant = merchants(:netflix)
    # Clear any existing recurring transactions
    @family.recurring_transactions.destroy_all
  end

  test "identify_patterns_for creates recurring transactions for patterns with 3+ occurrences" do
    # Create a series of transactions with same merchant and amount on similar days
    # Use dates within the last 3 months: today, 1 month ago, 2 months ago
    account = @family.accounts.first
    [ 0, 1, 2 ].each do |months_ago|
      transaction = Transaction.create!(
        merchant: @merchant,
        category: categories(:food_and_drink)
      )
      account.entries.create!(
        date: months_ago.months.ago.beginning_of_month + 5.days,
        amount: 15.99,
        currency: "USD",
        name: "Netflix Subscription",
        entryable: transaction
      )
    end

    assert_difference "@family.recurring_transactions.count", 1 do
      RecurringTransaction.identify_patterns_for(@family)
    end

    recurring = @family.recurring_transactions.last
    assert_equal @merchant, recurring.merchant
    assert_equal 15.99, recurring.amount
    assert_equal "USD", recurring.currency
    assert_equal "active", recurring.status
    assert_equal 3, recurring.occurrence_count
  end

  test "identify_patterns_for does not create recurring transaction for less than 3 occurrences" do
    # Create only 2 transactions
    account = @family.accounts.first
    2.times do |i|
      transaction = Transaction.create!(
        merchant: @merchant,
        category: categories(:food_and_drink)
      )
      account.entries.create!(
        date: (i + 1).months.ago.beginning_of_month + 5.days,
        amount: 15.99,
        currency: "USD",
        name: "Netflix Subscription",
        entryable: transaction
      )
    end

    assert_no_difference "@family.recurring_transactions.count" do
      RecurringTransaction.identify_patterns_for(@family)
    end
  end

  test "identify_patterns_for excludes transfer transactions" do
    account = @family.accounts.first

    [ 0, 1, 2 ].each do |months_ago|
      transaction = Transaction.create!(
        kind: "funds_movement",
        merchant: @merchant,
        category: categories(:food_and_drink)
      )
      account.entries.create!(
        date: months_ago.months.ago.beginning_of_month + 5.days,
        amount: 500,
        currency: "USD",
        name: "Monthly account transfer",
        entryable: transaction
      )
    end

    assert_no_difference "@family.recurring_transactions.count" do
      RecurringTransaction.identify_patterns_for(@family)
    end
  end

  test "identity signature normalizes names, amounts, and currency" do
    signature = RecurringTransaction.identity_signature_for(
      account_id: accounts(:depository).id,
      destination_account_id: nil,
      merchant_id: nil,
      name: "  Gym   Membership ",
      amount: "25.0000",
      currency: "usd"
    )
    equivalent_signature = RecurringTransaction.identity_signature_for(
      account_id: accounts(:depository).id,
      destination_account_id: nil,
      merchant_id: nil,
      name: "gym membership",
      amount: "25.00",
      currency: "USD"
    )

    assert_equal signature, equivalent_signature
  end

  test "identity signature distinguishes recurring transfer destinations" do
    source = accounts(:depository)
    common = {
      account_id: source.id,
      merchant_id: nil,
      name: "Monthly transfer",
      amount: 100,
      currency: "USD"
    }

    credit_card_signature = RecurringTransaction.identity_signature_for(
      **common,
      destination_account_id: accounts(:credit_card).id
    )
    investment_signature = RecurringTransaction.identity_signature_for(
      **common,
      destination_account_id: accounts(:investment).id
    )

    assert_not_equal credit_card_signature, investment_signature
  end

  test "calculate_next_expected_date handles end of month correctly" do
    recurring = @family.recurring_transactions.create!(
      merchant: @merchant,
      amount: 29.99,
      currency: "USD",
      expected_day_of_month: 31,
      last_occurrence_date: Date.new(2025, 1, 31),
      next_expected_date: Date.new(2025, 2, 28),
      status: "active"
    )

    # February doesn't have 31 days, should return last day of February
    next_date = recurring.calculate_next_expected_date(Date.new(2025, 1, 31))
    assert_equal Date.new(2025, 2, 28), next_date
  end

  test "should_be_inactive? returns true when last occurrence is over 2 months ago" do
    recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      amount: 19.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 3.months.ago.to_date,
      next_expected_date: 2.months.ago.to_date,
      status: "active"
    )

    assert recurring.should_be_inactive?
  end

  test "should_be_inactive? returns false when last occurrence is within 2 months" do
    recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      amount: 25.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: Date.current,
      status: "active"
    )

    assert_not recurring.should_be_inactive?
  end

  test "cleanup_stale_for marks inactive when no recent occurrences" do
    recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      amount: 35.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 3.months.ago.to_date,
      next_expected_date: 2.months.ago.to_date,
      status: "active"
    )

    RecurringTransaction.cleanup_stale_for(@family)

    assert_equal "inactive", recurring.reload.status
  end

  test "record_occurrence! updates recurring transaction with new occurrence" do
    recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: Date.current,
      status: "active",
      occurrence_count: 3
    )

    new_date = Date.current
    recurring.record_occurrence!(new_date)

    assert_equal new_date, recurring.last_occurrence_date
    assert_equal 4, recurring.occurrence_count
    assert_equal "active", recurring.status
    assert recurring.next_expected_date > new_date
  end

  test "ignore! suppresses recurring transaction without deleting detection memory" do
    recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: Date.current,
      status: "active",
      occurrence_count: 3
    )

    assert_no_difference "RecurringTransaction.count" do
      recurring.ignore!
    end

    assert_equal "ignored", recurring.reload.status
    assert_not_includes @family.recurring_transactions.visible, recurring
  end

  test "record_occurrence! does not reactivate ignored recurring transaction" do
    recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 1.month.ago.to_date,
      next_expected_date: Date.current,
      status: "ignored",
      occurrence_count: 3
    )

    assert_no_changes "recurring.reload.status" do
      assert_equal false, recurring.record_occurrence!(Date.current)
    end
  end

  test "create_subscription_plan! creates subscription and suppresses recurring candidate" do
    account = @family.accounts.first
    merchant = merchants(:amazon)

    [ 0, 1, 2 ].each do |months_ago|
      transaction = Transaction.create!(
        merchant: merchant,
        category: categories(:food_and_drink)
      )
      account.entries.create!(
        date: months_ago.months.ago.beginning_of_month + 5.days,
        amount: 45.99,
        currency: "USD",
        name: "Amazon Prime",
        entryable: transaction
      )
    end

    recurring = @family.recurring_transactions.create!(
      merchant: merchant,
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: Date.current,
      next_expected_date: 1.month.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )

    assert_difference "SubscriptionPlan.count", 1 do
      @subscription_plan = recurring.create_subscription_plan!
    end

    assert_equal "ignored", recurring.reload.status
    assert_equal account, @subscription_plan.account
    assert_equal merchant, @subscription_plan.merchant
    assert_equal "Amazon", @subscription_plan.name
    assert_equal recurring.amount, @subscription_plan.amount
    assert_equal recurring.next_expected_date, @subscription_plan.next_billing_at
    assert_equal recurring.id, @subscription_plan.metadata.dig("source", "id")
  end

  test "create_subscription_plan! reuses existing matching subscription" do
    merchant = merchants(:amazon)
    existing = @family.subscription_plans.create!(
      account: @family.accounts.first,
      merchant: merchant,
      name: "Amazon",
      amount: 45.99,
      currency: "USD",
      billing_cycle: "monthly",
      status: "active",
      payment_method: "manual",
      started_at: 1.month.ago.to_date,
      next_billing_at: 1.month.from_now.to_date,
      auto_renew: true
    )

    recurring = @family.recurring_transactions.create!(
      merchant: merchant,
      amount: 45.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: Date.current,
      next_expected_date: 1.month.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )

    assert_no_difference "SubscriptionPlan.count" do
      assert_equal existing, recurring.create_subscription_plan!
    end

    assert_equal "ignored", recurring.reload.status
  end

  test "create_subscription_plan! rejects recurring income" do
    recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      amount: -1000.00,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: Date.current,
      next_expected_date: 1.month.from_now.to_date,
      status: "active",
      occurrence_count: 3
    )

    assert_no_difference "SubscriptionPlan.count" do
      error = assert_raises(ArgumentError) { recurring.create_subscription_plan! }
      assert_equal "Only recurring expenses can become subscription plans", error.message
    end
  end

  test "create_subscription_plan! rejects recurring transfers" do
    recurring = @family.recurring_transactions.create!(
      account: accounts(:depository),
      destination_account: accounts(:credit_card),
      name: "Card payment",
      amount: 100,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: Date.current,
      next_expected_date: 1.month.from_now.to_date,
      status: "active",
      occurrence_count: 1,
      manual: true
    )

    assert_not recurring.subscription_candidate?
    assert_raises(ArgumentError) { recurring.create_subscription_plan! }
  end

  test "identify_patterns_for preserves sign for income transactions" do
    # Create recurring income transactions (negative amounts)
    account = @family.accounts.first
    [ 0, 1, 2 ].each do |months_ago|
      transaction = Transaction.create!(
        merchant: @merchant,
        category: categories(:income)
      )
      account.entries.create!(
        date: months_ago.months.ago.beginning_of_month + 15.days,
        amount: -1000.00,
        currency: "USD",
        name: "Monthly Salary",
        entryable: transaction
      )
    end

    assert_difference "@family.recurring_transactions.count", 1 do
      RecurringTransaction.identify_patterns_for(@family)
    end

    recurring = @family.recurring_transactions.last
    assert_equal @merchant, recurring.merchant
    assert_equal(-1000.00, recurring.amount)
    assert recurring.amount.negative?, "Income should have negative amount"
    assert_equal "USD", recurring.currency
    assert_equal "active", recurring.status
  end

  test "identify_patterns_for creates name-based recurring transactions for transactions without merchants" do
    # Create transactions without merchants (e.g., from CSV imports or standard accounts)
    account = @family.accounts.first
    [ 0, 1, 2 ].each do |months_ago|
      transaction = Transaction.create!(
        category: categories(:food_and_drink)
      )
      account.entries.create!(
        date: months_ago.months.ago.beginning_of_month + 10.days,
        amount: 25.00,
        currency: "USD",
        name: "Local Coffee Shop",
        entryable: transaction
      )
    end

    assert_difference "@family.recurring_transactions.count", 1 do
      RecurringTransaction.identify_patterns_for(@family)
    end

    recurring = @family.recurring_transactions.last
    assert_nil recurring.merchant
    assert_equal "Local Coffee Shop", recurring.name
    assert_equal 25.00, recurring.amount
    assert_equal "USD", recurring.currency
    assert_equal "active", recurring.status
    assert_equal 3, recurring.occurrence_count
  end

  test "identify_patterns_for creates separate patterns for same merchant but different names" do
    # Create two different recurring transactions from the same merchant
    account = @family.accounts.first

    # First pattern: Netflix Standard
    [ 0, 1, 2 ].each do |months_ago|
      transaction = Transaction.create!(
        merchant: @merchant,
        category: categories(:food_and_drink)
      )
      account.entries.create!(
        date: months_ago.months.ago.beginning_of_month + 5.days,
        amount: 15.99,
        currency: "USD",
        name: "Netflix Standard",
        entryable: transaction
      )
    end

    # Second pattern: Netflix Premium
    [ 0, 1, 2 ].each do |months_ago|
      transaction = Transaction.create!(
        merchant: @merchant,
        category: categories(:food_and_drink)
      )
      account.entries.create!(
        date: months_ago.months.ago.beginning_of_month + 10.days,
        amount: 19.99,
        currency: "USD",
        name: "Netflix Premium",
        entryable: transaction
      )
    end

    # Should create 2 patterns - one for each amount
    assert_difference "@family.recurring_transactions.count", 2 do
      RecurringTransaction.identify_patterns_for(@family)
    end
  end

  test "matching_transactions works with name-based recurring transactions" do
    account = @family.accounts.first

    # Create transactions for pattern
    [ 0, 1, 2 ].each do |months_ago|
      transaction = Transaction.create!(
        category: categories(:food_and_drink)
      )
      account.entries.create!(
        date: months_ago.months.ago.beginning_of_month + 15.days,
        amount: 50.00,
        currency: "USD",
        name: "Gym Membership",
        entryable: transaction
      )
    end

    RecurringTransaction.identify_patterns_for(@family)
    recurring = @family.recurring_transactions.last

    # Verify matching transactions finds the correct entries
    matches = recurring.matching_transactions
    assert_equal 3, matches.size
    assert matches.all? { |entry| entry.name == "Gym Membership" }
  end

  test "matching_transactions excludes transfer transactions with the same merchant and amount" do
    account = @family.accounts.first
    recurring = @family.recurring_transactions.create!(
      account: account,
      merchant: @merchant,
      amount: 15.99,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: Date.current,
      next_expected_date: 1.month.from_now.to_date,
      status: "active"
    )

    standard = Transaction.create!(merchant: @merchant, kind: "standard")
    transfer = Transaction.create!(merchant: @merchant, kind: "funds_movement")

    standard_entry = account.entries.create!(
      date: Date.current.beginning_of_month + 4.days,
      amount: 15.99,
      currency: "USD",
      name: "Netflix",
      entryable: standard
    )
    account.entries.create!(
      date: Date.current.beginning_of_month + 4.days,
      amount: 15.99,
      currency: "USD",
      name: "Netflix",
      entryable: transfer
    )

    assert_equal [ standard_entry.id ], recurring.matching_transactions.pluck(:id)
  end

  test "create_from_transfer stores both endpoints and matches the transfer pair" do
    source = accounts(:depository)
    destination = accounts(:credit_card)
    date = Date.current.beginning_of_month + 4.days
    outflow = source.entries.create!(
      date: date,
      amount: 250,
      currency: "USD",
      name: "Card payment",
      entryable: Transaction.new(kind: "cc_payment")
    )
    inflow = destination.entries.create!(
      date: date,
      amount: -250,
      currency: "USD",
      name: "Card payment",
      entryable: Transaction.new(kind: "funds_movement")
    )
    transfer = Transfer.create!(
      outflow_transaction: outflow.entryable,
      inflow_transaction: inflow.entryable,
      status: "confirmed"
    )

    recurring = RecurringTransaction.create_from_transfer(transfer)

    assert recurring.transfer?
    assert_equal source, recurring.account
    assert_equal destination, recurring.destination_account
    assert_equal [ outflow.id ], recurring.matching_transactions.pluck(:id)
    assert_equal source, recurring.projected_entry.source_account
    assert_equal destination, recurring.projected_entry.destination_account
  end

  test "recurring transfer rejects identical endpoints" do
    recurring = @family.recurring_transactions.build(
      account: accounts(:depository),
      destination_account: accounts(:depository),
      name: "Invalid transfer",
      amount: 100,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: Date.current,
      next_expected_date: 1.month.from_now.to_date,
      manual: true
    )

    assert_not recurring.valid?
    assert_includes recurring.errors[:destination_account], "cannot be the same as the source account"
  end

  test "validation requires either merchant or name" do
    recurring = @family.recurring_transactions.build(
      amount: 25.00,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: Date.current,
      next_expected_date: 1.month.from_now.to_date
    )

    assert_not recurring.valid?
    assert_includes recurring.errors[:base], "Either merchant or name must be present"
  end

  test "both merchant-based and name-based patterns can coexist" do
    account = @family.accounts.first

    # Create merchant-based pattern
    [ 0, 1, 2 ].each do |months_ago|
      transaction = Transaction.create!(
        merchant: @merchant,
        category: categories(:food_and_drink)
      )
      account.entries.create!(
        date: months_ago.months.ago.beginning_of_month + 5.days,
        amount: 15.99,
        currency: "USD",
        name: "Netflix Subscription",
        entryable: transaction
      )
    end

    # Create name-based pattern (no merchant)
    [ 0, 1, 2 ].each do |months_ago|
      transaction = Transaction.create!(
        category: categories(:one)
      )
      account.entries.create!(
        date: months_ago.months.ago.beginning_of_month + 1.days,
        amount: 1200.00,
        currency: "USD",
        name: "Monthly Rent",
        entryable: transaction
      )
    end

    assert_difference "@family.recurring_transactions.count", 2 do
      RecurringTransaction.identify_patterns_for(@family)
    end

    # Verify both types exist
    merchant_based = @family.recurring_transactions.where.not(merchant_id: nil).first
    name_based = @family.recurring_transactions.where(merchant_id: nil).first

    assert merchant_based.present?
    assert_equal @merchant, merchant_based.merchant

    assert name_based.present?
    assert_equal "Monthly Rent", name_based.name
  end

  test "create_from_transaction creates manual recurring transaction with variance" do
    account = @family.accounts.first

    # Create past transactions with varying amounts
    amounts = [ 100.00, 110.00, 95.00 ]

    amounts.each_with_index do |amt, i|
      transaction = Transaction.create!(
        merchant: @merchant,
        category: categories(:food_and_drink)
      )
      account.entries.create!(
        date: (i + 1).months.ago.beginning_of_month + 5.days,
        amount: amt,
        currency: "USD",
        name: "Variable Bill",
        entryable: transaction
      )
    end

    # Current transaction
    current_transaction = Transaction.create!(
      merchant: @merchant,
      category: categories(:food_and_drink)
    )
    current_entry = account.entries.create!(
      date: Date.current.beginning_of_month + 5.days,
      amount: 105.00,
      currency: "USD",
      name: "Variable Bill",
      entryable: current_transaction
    )

    recurring = RecurringTransaction.create_from_transaction(current_transaction)

    assert recurring.persisted?
    assert recurring.manual?
    assert_equal 4, recurring.occurrence_count
    assert_equal 95.00, recurring.expected_amount_min
    assert_equal 110.00, recurring.expected_amount_max
    assert_in_delta 102.5, recurring.expected_amount_avg, 0.01
  end

  test "matching_transactions handles variance for manual recurring transactions" do
    recurring = @family.recurring_transactions.create!(
      merchant: @merchant,
      amount: 100.00,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: Date.current,
      next_expected_date: 1.month.from_now.to_date,
      manual: true,
      expected_amount_min: 90.00,
      expected_amount_max: 110.00,
      expected_amount_avg: 100.00
    )

    account = @family.accounts.first

    # Match within variance
    t1 = Transaction.create!(merchant: @merchant, category: categories(:food_and_drink))
    e1 = account.entries.create!(
      date: 1.month.ago.beginning_of_month + 5.days,
      amount: 95.00,
      currency: "USD",
      entryable: t1,
      name: "Transaction 1"
    )

    # No match (outside variance)
    t2 = Transaction.create!(merchant: @merchant, category: categories(:food_and_drink))
    e2 = account.entries.create!(
      date: 2.months.ago.beginning_of_month + 5.days,
      amount: 150.00,
      currency: "USD",
      entryable: t2,
      name: "Transaction 2"
    )

    matches = recurring.matching_transactions
    assert_includes matches, e1
    assert_not_includes matches, e2
  end

  test "cleaner does not remove manual recurring transactions" do
    manual_recurring = @family.recurring_transactions.create!(
      merchant: @merchant,
      amount: 100.00,
      currency: "USD",
      expected_day_of_month: 5,
      last_occurrence_date: 7.months.ago.to_date,
      next_expected_date: 6.months.ago.to_date,
      status: "inactive",
      manual: true
    )

    auto_recurring = @family.recurring_transactions.create!(
      merchant: merchants(:amazon),
      amount: 50.00,
      currency: "USD",
      expected_day_of_month: 10,
      last_occurrence_date: 7.months.ago.to_date,
      next_expected_date: 6.months.ago.to_date,
      status: "inactive",
      manual: false
    )

    # Force updated_at to be old
    manual_recurring.update_columns(updated_at: 7.months.ago)
    auto_recurring.update_columns(updated_at: 7.months.ago)

    RecurringTransaction::Cleaner.new(@family).remove_old_inactive_transactions

    assert RecurringTransaction.exists?(manual_recurring.id)
    assert_not RecurringTransaction.exists?(auto_recurring.id)
  end
end
