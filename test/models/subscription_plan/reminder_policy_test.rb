require "test_helper"

class SubscriptionPlan::ReminderPolicyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  test "sends and deduplicates a two-day trial reminder" do
    subscription = subscription_plans(:netflix_subscription)
    subscription.update!(status: "trial", trial_ends_at: 2.days.from_now.to_date)
    policy = SubscriptionPlan::ReminderPolicy.new

    assert_emails 1 do
      assert_equal({ renewal: 0, trial: 1 }, policy.deliver_upcoming!)
    end

    assert_emails 0 do
      assert_equal({ renewal: 0, trial: 0 }, policy.deliver_upcoming!)
    end
  end

  test "repairs legacy active records with a future trial date through reminder delivery" do
    subscription = subscription_plans(:netflix_subscription)
    subscription.update!(status: "active", trial_ends_at: 2.days.from_now.to_date)

    assert_emails 1 do
      assert_equal({ renewal: 0, trial: 1 }, SubscriptionPlan::ReminderPolicy.new.deliver_upcoming!)
    end
  end

  test "sends trial expiration once" do
    subscription = subscription_plans(:netflix_subscription)
    subscription.update!(status: "trial", trial_ends_at: Date.current)
    policy = SubscriptionPlan::ReminderPolicy.new

    assert_emails 1 do
      assert policy.deliver_trial_expired!(subscription)
    end

    assert_emails 0 do
      assert_not policy.deliver_trial_expired!(subscription)
    end
  end

  test "does not record delivery for a reserved example recipient" do
    subscription = subscription_plans(:netflix_subscription)
    subscription.update!(status: "trial", trial_ends_at: 2.days.from_now.to_date)
    subscription.family.primary_user.update!(email: "uat@example.com")

    assert_emails 0 do
      assert_equal({ renewal: 0, trial: 0 }, SubscriptionPlan::ReminderPolicy.new.deliver_upcoming!)
    end
    assert_not subscription.audit_logs.where(event: "subscription.notification_sent").exists?
  end
end
