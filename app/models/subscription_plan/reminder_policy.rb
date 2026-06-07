class SubscriptionPlan::ReminderPolicy
  RENEWAL_MILESTONES = [ 3, 1 ].freeze
  TRIAL_MILESTONES = [ 3, 2, 1 ].freeze

  attr_reader :date

  def initialize(date: Date.current)
    @date = date.to_date
  end

  def deliver_upcoming!
    renewal_count = deliver_renewal_reminders
    trial_count = deliver_trial_reminders

    { renewal: renewal_count, trial: trial_count }
  end

  def deliver_trial_expired!(subscription)
    deliver_once!(
      subscription,
      kind: "trial_expired",
      occurrence_date: subscription.trial_ends_at
    ) do
      SubscriptionMailer.trial_expired(subscription).deliver_now
    end
  end

  private
    def deliver_renewal_reminders
      RENEWAL_MILESTONES.sum do |days_ahead|
        delivered = 0
        SubscriptionPlan.active.where(next_billing_at: date + days_ahead.days).find_each do |subscription|
          delivered += 1 if deliver_once!(
            subscription,
            kind: "renewal",
            occurrence_date: subscription.next_billing_at,
            days_remaining: days_ahead
          ) do
            SubscriptionMailer.renewal_reminder(subscription, days_ahead).deliver_now
          end
        end
        delivered
      end
    end

    def deliver_trial_reminders
      TRIAL_MILESTONES.sum do |days_ahead|
        delivered = 0
        SubscriptionPlan.where(status: %w[trial active], trial_ends_at: date + days_ahead.days).find_each do |subscription|
          delivered += 1 if deliver_once!(
            subscription,
            kind: "trial_ending",
            occurrence_date: subscription.trial_ends_at,
            days_remaining: days_ahead
          ) do
            SubscriptionMailer.trial_ending(subscription, days_ahead).deliver_now
          end
        end
        delivered
      end
    end

    def deliver_once!(subscription, kind:, occurrence_date:, days_remaining: nil)
      key = [ kind, subscription.id, occurrence_date, days_remaining ].compact.join(":")
      return false if subscription.audit_logs.where(event: "subscription.notification_sent")
        .where("changeset ->> 'key' = ?", key).exists?
      return false unless deliverable_recipient?(subscription)

      yield
      Recurring::EventRecorder.record!(
        record: subscription,
        event: "subscription.notification_sent",
        key: key,
        title: kind.humanize,
        detail: notification_detail(kind, days_remaining),
        metadata: {
          kind: kind,
          occurrence_date: occurrence_date,
          days_remaining: days_remaining
        }.compact
      )
      true
    end

    def deliverable_recipient?(subscription)
      email = subscription.family.primary_user&.email.to_s.downcase
      domain = email.split("@", 2).last
      deliverable = email.present? && domain.present? &&
        domain != "example.com" &&
        !domain.end_with?(".example")

      Rails.logger.warn("Subscription reminder skipped: family #{subscription.family_id} needs a deliverable primary email") unless deliverable
      deliverable
    end

    def notification_detail(kind, days_remaining)
      return "Trial expiration notification sent." if kind == "trial_expired"

      "#{kind.humanize} notification sent #{days_remaining} #{'day'.pluralize(days_remaining)} before occurrence."
    end
end
