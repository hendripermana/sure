require "test_helper"

class GoldAutoRevaluationJobTest < ActiveJob::TestCase
  test "revalues enabled precious metal accounts from the selected source" do
    precious_metal = accounts(:precious_metal).precious_metal
    precious_metal.update!(
      auto_revalue: true,
      price_source: "antam",
      metal_type: "gold",
      manual_price_currency: "IDR"
    )
    GoldPrice.create!(
      date: Date.new(2026, 6, 7),
      source: "antam",
      price_per_gram: 2_888_000,
      currency: "IDR"
    )

    result = GoldAutoRevaluationJob.perform_now(date: "2026-06-07")

    assert_equal({ updated: 1, errors: 0 }, result)
    assert_equal 2_888_000, precious_metal.reload.manual_price
  end
end
