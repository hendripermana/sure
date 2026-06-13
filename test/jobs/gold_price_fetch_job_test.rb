require "test_helper"

class GoldPriceFetchJobTest < ActiveJob::TestCase
  test "enqueues revaluation after a successful fetch" do
    result = GoldPriceFetcher::Result.new(true, { price_per_gram: 2_888_000 }, nil)
    GoldPriceFetcher.any_instance.expects(:fetch).returns(result)

    assert_enqueued_with job: GoldAutoRevaluationJob, args: [ { date: "2026-06-07" } ] do
      GoldPriceFetchJob.perform_now(date: "2026-06-07")
    end
  end

  test "does not enqueue revaluation after a parse failure" do
    result = GoldPriceFetcher::Result.new(false, nil, "markup changed")
    GoldPriceFetcher.any_instance.expects(:fetch).returns(result)

    assert_no_enqueued_jobs only: GoldAutoRevaluationJob do
      GoldPriceFetchJob.perform_now(date: "2026-06-07")
    end
  end
end
