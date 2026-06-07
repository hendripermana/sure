require "test_helper"

class SubscriptionMailerTest < ActionMailer::TestCase
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
