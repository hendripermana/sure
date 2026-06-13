require "test_helper"

class Recurring::ScheduleTest < ActiveSupport::TestCase
  test "advances flexible intervals" do
    assert_equal Date.new(2026, 6, 10), Recurring::Schedule.new(count: 3, unit: "day").advance(Date.new(2026, 6, 7))
    assert_equal Date.new(2026, 6, 21), Recurring::Schedule.new(count: 2, unit: "week").advance(Date.new(2026, 6, 7))
    assert_equal Date.new(2026, 8, 7), Recurring::Schedule.new(count: 2, unit: "month").advance(Date.new(2026, 6, 7))
  end

  test "uses calendar-safe month advancement" do
    schedule = Recurring::Schedule.new(count: 1, unit: "month")

    assert_equal Date.new(2026, 2, 28), schedule.advance(Date.new(2026, 1, 31))
    assert_equal Date.new(2028, 2, 29), schedule.advance(Date.new(2028, 1, 31))
  end

  test "projects legacy cycles and readable labels" do
    subscription = subscription_plans(:netflix_subscription)
    subscription.billing_cycle = "quarterly"

    schedule = Recurring::Schedule.from_subscription(subscription)

    assert_equal 3, schedule.count
    assert_equal "month", schedule.unit
    assert_equal "Every 3 months", schedule.label
  end

  test "one-time schedules do not advance" do
    schedule = Recurring::Schedule.new(count: 1, unit: "once")

    assert_nil schedule.advance(Date.current)
    assert_equal "One-time", schedule.label
  end

  test "round trips a flexible service frequency" do
    service = ServiceMerchant.new(billing_frequency: "2_week")
    schedule = Recurring::Schedule.from_service_merchant(service)

    assert_equal 2, schedule.count
    assert_equal "week", schedule.unit
    assert_equal "2_week", schedule.service_frequency
    assert_equal "Every 2 weeks", schedule.label
  end
end
