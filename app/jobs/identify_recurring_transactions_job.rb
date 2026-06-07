require "digest"

class IdentifyRecurringTransactionsJob < ApplicationJob
  queue_as :default

  DEBOUNCE_DELAY = 30.seconds
  CACHE_TTL = DEBOUNCE_DELAY + 1.minute
  ADVISORY_LOCK_NAMESPACE = 1_947_203_321

  def self.schedule_for(family)
    scheduled_at = Time.current.to_f
    Rails.cache.write(cache_key(family.id), scheduled_at, expires_in: CACHE_TTL)
    set(wait: DEBOUNCE_DELAY).perform_later(family.id, scheduled_at)
  end

  def self.cache_key(family_id)
    "recurring_transaction_identify:#{family_id}"
  end

  def perform(family_id, scheduled_at)
    family = Family.find_by(id: family_id)
    return unless family
    return if superseded?(family_id, scheduled_at)
    return if Sync.any_incomplete_for?(family)

    with_advisory_lock(family_id) do
      RecurringTransaction.identify_patterns_for(family)
    end
  end

  private
    def superseded?(family_id, scheduled_at)
      latest_scheduled_at = Rails.cache.read(self.class.cache_key(family_id))
      latest_scheduled_at.present? && latest_scheduled_at.to_f > scheduled_at.to_f
    end

    def with_advisory_lock(family_id)
      connection = ActiveRecord::Base.connection
      lock_id = Digest::SHA256.hexdigest(family_id.to_s).to_i(16) % (2**31)
      lock_sql = ActiveRecord::Base.sanitize_sql_array(
        [ "SELECT pg_try_advisory_lock(?, ?)", ADVISORY_LOCK_NAMESPACE, lock_id ]
      )
      acquired = connection.select_value(lock_sql)
      return unless ActiveModel::Type::Boolean.new.cast(acquired)

      yield
    ensure
      if acquired
        unlock_sql = ActiveRecord::Base.sanitize_sql_array(
          [ "SELECT pg_advisory_unlock(?, ?)", ADVISORY_LOCK_NAMESPACE, lock_id ]
        )
        connection.select_value(unlock_sql)
      end
    end
end
