require "test_helper"

class ReconcileTransactionJobTest < ActiveJob::TestCase
  test "runs scoped reconciliation for a transaction entry" do
    entry = entries(:transaction)
    reconciler = mock
    notifier = mock

    Recurring::Reconciler.expects(:new).with(
      entry.account.family,
      as_of: entry.date,
      entry: entry
    ).returns(reconciler)
    reconciler.expects(:reconcile!).once.returns([ mock ])
    Recurring::Notifier.expects(:new).with(
      entry.account.family,
      as_of: entry.date
    ).returns(notifier)
    notifier.expects(:deliver!).once

    ReconcileTransactionJob.perform_now(entry.id)
  end

  test "skips entries already linked to a subscription renewal" do
    entry = entries(:transaction)
    SubscriptionRenewal.expects(:where).with(entry_id: entry.id).returns(stub(exists?: true))
    Recurring::Reconciler.expects(:new).never

    ReconcileTransactionJob.perform_now(entry.id)
  end
end
