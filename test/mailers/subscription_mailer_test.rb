require "test_helper"

class SubscriptionMailerTest < ActionMailer::TestCase
  test "recurring anomaly targets the family primary user" do
    family = families(:dylan_family)
    subscription = subscription_plans(:netflix_subscription)
    event = Recurring::EventRecorder.record!(
      record: subscription,
      event: "recurring.missed",
      key: "mailer-test",
      title: "Missed payment",
      detail: "No matching payment was found.",
      severity: "warning"
    )

    mail = SubscriptionMailer.recurring_anomaly(family, subscription, event)

    assert_equal [ family.primary_user.email ], mail.to
    assert_match subscription.name, mail.subject
    assert_match "No matching payment was found.", mail.body.encoded
  end

  test "trial ending renders the milestone and subscription link" do
    subscription = subscription_plans(:netflix_subscription)
    subscription.update!(status: "trial", trial_ends_at: 2.days.from_now.to_date)

    mail = SubscriptionMailer.trial_ending(subscription, 2)

    assert_equal [ subscription.family.primary_user.email ], mail.to
    assert_match "trial ends in 2 days", mail.subject
    assert_match "2 days", mail.body.encoded
    assert_match "/subscription_plans/#{subscription.id}", mail.body.encoded
  end

  test "trial expired renders the lifecycle notice" do
    subscription = subscription_plans(:netflix_subscription)
    subscription.update!(status: "trial", trial_ends_at: Date.current)

    mail = SubscriptionMailer.trial_expired(subscription)

    assert_equal [ subscription.family.primary_user.email ], mail.to
    assert_match "trial has expired", mail.subject
    assert_match "Subscription Manager", mail.body.encoded
    assert_match "/subscription_plans/#{subscription.id}", mail.body.encoded
  end
end
