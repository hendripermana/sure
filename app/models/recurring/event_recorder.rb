require "zlib"

module Recurring
  class EventRecorder
    def self.record!(record:, event:, key:, title:, detail:, severity: "info", metadata: {})
      new(
        record: record,
        event: event,
        key: key,
        title: title,
        detail: detail,
        severity: severity,
        metadata: metadata
      ).record!
    end

    def initialize(record:, event:, key:, title:, detail:, severity:, metadata:)
      @record = record
      @event = event
      @key = key
      @title = title
      @detail = detail
      @severity = severity
      @metadata = metadata
    end

    def record!
      AuditLog.transaction do
        lock_key!

        existing_event || AuditLog.create!(
          auditable: record,
          event: event,
          changeset: {
            "key" => key,
            "title" => title,
            "detail" => detail,
            "severity" => severity,
            "metadata" => metadata
          },
          user_id: Current.user&.id,
          ip_address: Current.ip_address
        )
      end
    end

    private
      attr_reader :record, :event, :key, :title, :detail, :severity, :metadata

      def existing_event
        AuditLog
          .where(auditable: record, event: event)
          .where("changeset ->> 'key' = ?", key)
          .first
      end

      def lock_key!
        lock_id = Zlib.crc32("#{record.class.name}:#{record.id}:#{event}:#{key}")
        lock_id -= 2**32 if lock_id >= 2**31
        AuditLog.connection.raw_connection.exec_params(
          "SELECT pg_advisory_xact_lock($1)",
          [ lock_id ]
        )
      end
  end
end
