class GoldAutoRevaluationJob < ApplicationJob
  queue_as :scheduled

  def perform(date: Date.current.to_s)
    as_of = Date.parse(date)
    updated = 0
    errors = 0

    PreciousMetal.where(auto_revalue: true).find_each do |pm|
      if pm.apply_auto_revaluation!(as_of: as_of)
        updated += 1
      end
    rescue => e
      errors += 1
      Rails.logger.error("GoldAutoRevaluationJob: failed for PM #{pm.id}: #{e.message}")
    end

    Rails.logger.info("GoldAutoRevaluationJob: updated=#{updated}, errors=#{errors}")
    { updated: updated, errors: errors }
  end
end
