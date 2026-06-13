module Recurring
  class Notifier
    ALERT_STATUSES = %w[missed duplicate amount_changed unexpected_renewal].freeze

    attr_reader :family, :as_of

    def initialize(family, as_of: Date.current)
      @family = family
      @as_of = as_of.to_date
    end

    def deliver!
      alert_events.find_each.count do |event|
        deliver_event(event)
      end
    end

    private
      def alert_events
        AuditLog
          .where(auditable_type: %w[SubscriptionPlan RecurringTransaction])
          .where(event: ALERT_STATUSES.map { |status| "recurring.#{status}" })
          .where(created_at: 7.days.ago.beginning_of_day..Time.current)
          .where.not(id: delivered_event_ids)
      end

      def delivered_event_ids
        AuditLog.where(event: "recurring.notification_sent")
          .where("changeset -> 'metadata' ->> 'family_id' = ?", family.id.to_s)
          .pluck(Arel.sql("changeset -> 'metadata' ->> 'source_event_id'"))
      end

      def deliver_event(event)
        commitment = event.auditable
        return false unless commitment&.family_id == family.id

        SubscriptionMailer.recurring_anomaly(family, commitment, event).deliver_later
        EventRecorder.record!(
          record: commitment,
          event: "recurring.notification_sent",
          key: "notification:#{event.id}",
          title: "Notification sent",
          detail: event.changeset["title"],
          metadata: {
            family_id: family.id,
            source_event_id: event.id,
            delivered_on: as_of
          }
        )
        true
      end
  end
end
