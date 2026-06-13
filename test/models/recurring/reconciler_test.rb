require "test_helper"

class Recurring::ReconcilerTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @account = accounts(:depository)
    @merchant = merchants(:amazon)
  end

  test "matches an actual transaction and remains idempotent" do
    recurring_transaction = create_recurring_transaction(
      name: "Reconciler Gym",
      expected_date: 2.days.ago.to_date
    )
    entry = create_entry(
      name: recurring_transaction.name,
      amount: recurring_transaction.amount,
      date: recurring_transaction.next_expected_date
    )

    result = Recurring::Reconciler.new(@family).reconcile!.find do |candidate|
      candidate.commitment == recurring_transaction
    end

    assert_equal "paid", result.status
    match_key = "RecurringTransaction:#{recurring_transaction.id}:#{recurring_transaction.next_expected_date}"
    assert_equal recurring_transaction.id, entry.transaction.reload.extra.dig("recurring_matches", match_key, "commitment_id")
    assert_equal 1, recurring_transaction.audit_logs.where(event: "recurring.paid").count

    Recurring::Reconciler.new(@family).reconcile!

    assert_equal 1, recurring_transaction.audit_logs.where(event: "recurring.paid").count
  end

  test "classifies duplicate and missed occurrences" do
    duplicate = create_recurring_transaction(
      name: "Duplicate Membership",
      expected_date: 2.days.ago.to_date
    )
    2.times do
      create_entry(
        name: duplicate.name,
        amount: duplicate.amount,
        date: duplicate.next_expected_date
      )
    end
    missed = create_recurring_transaction(
      name: "Missing Membership",
      expected_date: 10.days.ago.to_date
    )

    results = Recurring::Reconciler.new(@family).reconcile!

    assert_equal "duplicate", results.find { |result| result.commitment == duplicate }.status
    assert_equal "missed", results.find { |result| result.commitment == missed }.status
  end

  test "flags a charge for a paused subscription as an unexpected renewal" do
    subscription = subscription_plans(:netflix_subscription)
    subscription.update!(status: "paused", amount: 22, merchant: @merchant)
    create_entry(
      name: subscription.name,
      amount: subscription.amount,
      date: Date.current
    ).transaction.update!(merchant: subscription.merchant)

    result = Recurring::Reconciler.new(@family).reconcile!.find do |candidate|
      candidate.commitment == subscription
    end

    assert_equal "unexpected_renewal", result.status
    assert subscription.audit_logs.where(event: "recurring.unexpected_renewal").exists?
  end

  test "matches a merchantless manual transaction by normalized service name" do
    subscription = subscription_plans(:netflix_subscription)
    subscription.update!(status: "paused", amount: 22, merchant: @merchant)
    entry = create_entry(
      name: "Subscription: #{@merchant.name}",
      amount: subscription.amount,
      date: Date.current
    )

    result = Recurring::Reconciler.new(
      @family,
      as_of: entry.date,
      entry: entry
    ).reconcile!.find { |candidate| candidate.commitment == subscription }

    assert_equal "unexpected_renewal", result.status
    assert_equal [ entry ], result.entries
  end

  test "reconciles the latest renewal after next billing advances" do
    subscription = subscription_plans(:netflix_subscription)
    expected_date = Date.current
    subscription.update!(
      amount: 100,
      merchant: @merchant,
      next_billing_at: expected_date.next_month
    )
    entry = create_entry(
      name: subscription.name,
      amount: 125,
      date: expected_date
    )
    entry.transaction.update!(merchant: @merchant)
    subscription.subscription_renewals.create!(
      account: @account,
      entry: entry,
      cycle_number: subscription.next_cycle_number,
      billing_period_start: expected_date,
      billing_period_end: expected_date.next_month,
      template_amount: 100,
      actual_amount: 125,
      currency: "USD",
      paid_at: expected_date,
      status: "paid"
    )

    result = Recurring::Reconciler.new(@family, as_of: expected_date).reconcile!.find do |candidate|
      candidate.commitment == subscription && candidate.expected_date == expected_date
    end

    assert_equal "amount_changed", result.status
    assert_equal [ entry.id ], result.entries.map(&:id)
    assert subscription.audit_logs.where(event: "recurring.amount_changed").exists?
  end

  test "matching a current subscription payment advances its schedule" do
    subscription = subscription_plans(:netflix_subscription)
    expected_date = Date.current
    subscription.subscription_renewals.destroy_all
    subscription.update!(
      amount: 25,
      merchant: @merchant,
      next_billing_at: expected_date
    )
    entry = create_entry(
      name: subscription.name,
      amount: subscription.amount,
      date: expected_date
    )
    entry.transaction.update!(merchant: @merchant)

    Recurring::Reconciler.new(
      @family,
      as_of: expected_date,
      entry: entry
    ).reconcile!

    assert_equal expected_date.next_month, subscription.reload.next_billing_at
    assert_equal entry, subscription.subscription_renewals.last.entry
  end

  private
    def create_recurring_transaction(name:, expected_date:)
      @family.recurring_transactions.create!(
        name: name,
        account: @account,
        amount: 42,
        currency: "USD",
        expected_day_of_month: expected_date.day,
        last_occurrence_date: expected_date.prev_month,
        next_expected_date: expected_date,
        status: "active",
        occurrence_count: 4
      )
    end

    def create_entry(name:, amount:, date:)
      @account.entries.create!(
        name: name,
        amount: amount,
        currency: "USD",
        date: date,
        entryable: Transaction.new
      )
    end
end
