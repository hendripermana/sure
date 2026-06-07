require "test_helper"

class IdentifyRecurringTransactionsJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
    @scheduled_at = Time.current.to_f
    Sync.for_family(@family).incomplete.destroy_all
  end

  test "schedule_for records the latest request and enqueues a delayed job" do
    Rails.cache.expects(:write).with(
      IdentifyRecurringTransactionsJob.cache_key(@family.id),
      instance_of(Float),
      expires_in: IdentifyRecurringTransactionsJob::CACHE_TTL
    )

    assert_enqueued_with(job: IdentifyRecurringTransactionsJob) do
      IdentifyRecurringTransactionsJob.schedule_for(@family)
    end
  end

  test "runs identification when no family sync is incomplete" do
    Rails.cache.stubs(:read).returns(nil)
    RecurringTransaction.expects(:identify_patterns_for).with(@family).once

    IdentifyRecurringTransactionsJob.perform_now(@family.id, @scheduled_at)
  end

  test "skips identification while a family sync is incomplete" do
    Sync.create!(syncable: @family, status: "pending")
    Rails.cache.stubs(:read).returns(nil)
    RecurringTransaction.expects(:identify_patterns_for).never

    IdentifyRecurringTransactionsJob.perform_now(@family.id, @scheduled_at)
  end

  test "skips a job superseded by a newer schedule" do
    Rails.cache.stubs(:read).with(
      IdentifyRecurringTransactionsJob.cache_key(@family.id)
    ).returns(@scheduled_at + 1)
    RecurringTransaction.expects(:identify_patterns_for).never

    IdentifyRecurringTransactionsJob.perform_now(@family.id, @scheduled_at)
  end

  test "skips identification when the family no longer exists" do
    RecurringTransaction.expects(:identify_patterns_for).never

    IdentifyRecurringTransactionsJob.perform_now(SecureRandom.uuid, @scheduled_at)
  end
end
