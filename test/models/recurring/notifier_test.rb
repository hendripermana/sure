require "test_helper"

class Recurring::NotifierTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  test "delivers an anomaly once" do
    family = families(:dylan_family)
    subscription = subscription_plans(:netflix_subscription)
    event = Recurring::EventRecorder.record!(
      record: subscription,
      event: "recurring.amount_changed",
      key: "amount-change-test",
      title: "Amount changed",
      detail: "Expected 10, observed 12.",
      severity: "warning"
    )

    assert_enqueued_emails 1 do
      assert_equal 1, Recurring::Notifier.new(family).deliver!
    end

    assert_equal 0, Recurring::Notifier.new(family).deliver!
    assert subscription.audit_logs.where(event: "recurring.notification_sent")
      .where("changeset -> 'metadata' ->> 'source_event_id' = ?", event.id.to_s)
      .exists?
  end
end
