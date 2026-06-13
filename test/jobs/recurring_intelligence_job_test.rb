require "test_helper"

class RecurringIntelligenceJobTest < ActiveJob::TestCase
  test "reconciles and notifies every family" do
    Family.all.each do |family|
      reconciler = mock
      notifier = mock

      Recurring::Reconciler.expects(:new).with(family, as_of: Date.current).returns(reconciler)
      reconciler.expects(:reconcile!).once
      Recurring::Notifier.expects(:new).with(family, as_of: Date.current).returns(notifier)
      notifier.expects(:deliver!).once
    end

    RecurringIntelligenceJob.perform_now(Date.current)
  end
end
