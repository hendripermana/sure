class GoldPriceFetchJob < ApplicationJob
  queue_as :scheduled

  # Transient network/timeout errors should retry
  retry_on Net::OpenTimeout, wait: :exponentially_longer, attempts: 3
  retry_on Net::ReadTimeout, wait: :exponentially_longer, attempts: 3
  retry_on SocketError, wait: :exponentially_longer, attempts: 3
  retry_on Errno::ECONNRESET, wait: :exponentially_longer, attempts: 3
  retry_on GoldPriceFetcher::TransientError, wait: :exponentially_longer, attempts: 3

  def perform(source: "harga_emas_org", date: Date.current.to_s)
    result = GoldPriceFetcher.new.fetch(source: source.to_sym, date: Date.parse(date))

    if result.success?
      GoldAutoRevaluationJob.perform_later(date: date)
    else
      Rails.logger.warn("GoldPriceFetchJob failed to fetch price from #{source}: #{result.error}")
    end

    result
  end
end
