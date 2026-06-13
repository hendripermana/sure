class RecurringIntelligenceJob < ApplicationJob
  queue_as :scheduled

  def perform(date = Date.current)
    Family.find_each do |family|
      Recurring::Reconciler.new(family, as_of: date).reconcile!
      Recurring::Notifier.new(family, as_of: date).deliver!
    rescue => error
      Rails.logger.error(
        {
          at: "RecurringIntelligenceJob",
          family_id: family.id,
          date: date,
          error: error.message
        }.to_json
      )
      Sentry.capture_exception(error, tags: { job: self.class.name, family_id: family.id }) if defined?(Sentry)
    end
  end
end
