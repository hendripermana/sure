module Recurring
  class Schedule
    UNITS = %w[day week month year once].freeze
    LEGACY_CYCLES = {
      "monthly" => [ 1, "month" ],
      "quarterly" => [ 3, "month" ],
      "annual" => [ 1, "year" ],
      "biennial" => [ 2, "year" ],
      "one_time" => [ 1, "once" ]
    }.freeze

    attr_reader :count, :unit

    def self.from_subscription(subscription)
      metadata = subscription.metadata.to_h.fetch("schedule", {})
      legacy_count, legacy_unit = LEGACY_CYCLES.fetch(subscription.billing_cycle)

      new(
        count: metadata.fetch("count", legacy_count),
        unit: metadata.fetch("unit", legacy_unit)
      )
    end

    def self.from_recurring_transaction(recurring_transaction)
      previous_date = recurring_transaction.last_occurrence_date
      next_date = recurring_transaction.next_expected_date
      return new(count: 1, unit: "month") if previous_date.blank? || next_date.blank?

      days = (next_date - previous_date).to_i
      return new(count: days / 7, unit: "week") if days.positive? && (days % 7).zero? && days < 28
      return new(count: days, unit: "day") if days.positive? && days < 28

      new(count: 1, unit: "month")
    end

    def self.from_service_merchant(service_merchant)
      frequency = service_merchant.billing_frequency.to_s
      return new(count: 1, unit: "month") if frequency.blank?

      legacy = {
        "daily" => [ 1, "day" ],
        "weekly" => [ 1, "week" ],
        "monthly" => [ 1, "month" ],
        "quarterly" => [ 3, "month" ],
        "annual" => [ 1, "year" ],
        "biennial" => [ 2, "year" ],
        "one_time" => [ 1, "once" ]
      }[frequency]
      count, unit = legacy || frequency.match(/\A(\d+)_(day|week|month|year)\z/)&.captures

      new(count: count || 1, unit: unit || "month")
    end

    def initialize(count:, unit:)
      @unit = unit.to_s
      @count = @unit == "once" ? 1 : Integer(count)

      raise ArgumentError, "Interval count must be greater than zero" unless @count.positive?
      raise ArgumentError, "Unsupported interval unit: #{@unit}" unless UNITS.include?(@unit)
    end

    def advance(date)
      return nil if once?

      date.to_date.advance(unit.pluralize.to_sym => count)
    end

    def occurrences(first_date, through:)
      return [] if first_date.blank?

      date = first_date.to_date
      dates = []

      while date <= through.to_date
        dates << date
        date = advance(date)
        break if date.blank?
      end

      dates
    end

    def monthly_multiplier
      case unit
      when "day" then 30.to_d / count
      when "week" then 52.to_d / 12 / count
      when "month" then 1.to_d / count
      when "year" then 1.to_d / (12 * count)
      else 0.to_d
      end
    end

    def yearly_multiplier
      monthly_multiplier * 12
    end

    def label
      return "One-time" if once?
      return unit == "day" ? "Daily" : unit == "week" ? "Weekly" : unit == "month" ? "Monthly" : "Annually" if count == 1

      "Every #{count} #{unit.pluralize(count)}"
    end

    def legacy_cycle
      LEGACY_CYCLES.find { |_name, value| value == [ count, unit ] }&.first || "monthly"
    end

    def once?
      unit == "once"
    end

    def to_h
      { "count" => count, "unit" => unit }
    end

    def service_frequency
      return "one_time" if once?

      {
        [ 1, "day" ] => "daily",
        [ 1, "week" ] => "weekly",
        [ 1, "month" ] => "monthly",
        [ 3, "month" ] => "quarterly",
        [ 1, "year" ] => "annual",
        [ 2, "year" ] => "biennial"
      }.fetch([ count, unit ], "#{count}_#{unit}")
    end
  end
end
