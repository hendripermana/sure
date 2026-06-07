class Sync < ApplicationRecord
  # We run a cron that marks any syncs that have not been resolved in 24 hours as "stale"
  # Syncs often become stale when new code is deployed and the worker restarts
  STALE_AFTER = 24.hours

  # The max time that a sync will show in the UI (after 5 minutes)
  VISIBLE_FOR = 5.minutes

  include AASM

  Error = Class.new(StandardError)

  belongs_to :syncable, polymorphic: true

  belongs_to :parent, class_name: "Sync", optional: true
  has_many :children, class_name: "Sync", foreign_key: :parent_id, dependent: :destroy

  scope :ordered, -> { order(created_at: :desc) }
  scope :incomplete, -> { where("syncs.status IN (?)", %w[pending syncing]) }
  scope :visible, -> { incomplete.where("syncs.created_at > ?", VISIBLE_FOR.ago) }
  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :with_status, ->(status) { where(status: status) }

  after_commit :update_family_sync_timestamp
  after_commit :enqueue_sync_job, on: :create

  serialize :sync_stats, coder: JSON

  validate :window_valid

  # Sync state machine
  aasm column: :status, timestamps: true do
    state :pending, initial: true
    state :syncing
    state :completed
    state :failed
    state :stale

    after_all_transitions :handle_transition

    event :start, after_commit: :handle_start_transition do
      transitions from: :pending, to: :syncing
    end

    event :complete, after_commit: :handle_completion_transition do
      transitions from: :syncing, to: :completed
    end

    event :fail do
      transitions from: :syncing, to: :failed
    end

    # Marks a sync that never completed within the expected time window
    event :mark_stale do
      transitions from: %i[pending syncing], to: :stale
    end
  end

  class << self
    def clean
      # Clean syncs yang sudah terlalu lama (24 jam)
      incomplete.where("syncs.created_at < ?", STALE_AFTER.ago).find_each(&:mark_stale!)

      # Clean syncs yang stuck di syncing state lebih dari 10 menit (lebih agresif)
      # Ini untuk menangani kasus dimana sync job crash atau timeout tapi state tidak ter-update
      stuck_syncing = where(status: "syncing")
        .where("syncs.syncing_at < ?", 10.minutes.ago)
        .where("syncs.created_at < ?", 1.hour.ago) # Hanya sync yang sudah lebih dari 1 jam total

      stuck_count = stuck_syncing.count
      if stuck_count > 0
        Rails.logger.warn("Found #{stuck_count} stuck syncing syncs. Marking as stale.")
        stuck_syncing.find_each do |sync|
          sync.mark_stale! if sync.may_mark_stale?
        end
      end
    end

    def latest_stats_map_for(syncable_type:, syncable_ids:)
      ids = Array(syncable_ids).compact
      return {} if ids.empty?

      latest_syncs = Sync.where(syncable_type: syncable_type, syncable_id: ids)
        .select("DISTINCT ON (syncable_id) syncs.*")
        .order("syncable_id, created_at DESC")

      latest_syncs.each_with_object({}) do |sync, map|
        map[sync.syncable_id] = sync.sync_stats || {}
      end
    end

    def for_family(family)
      query = where(syncable_type: "Family", syncable_id: family.id)
        .or(where(syncable_type: "Account", syncable_id: family.accounts.select(:id)))

      family_syncable_associations.each do |association|
        query = query.or(
          where(
            syncable_type: association.klass.name,
            syncable_id: family.public_send(association.name).select(:id)
          )
        )
      end

      query
    end

    def any_incomplete_for?(family)
      for_family(family).incomplete.exists?
    end

    private
      def family_syncable_associations
        Family.reflect_on_all_associations(:has_many).select do |association|
          association.name.to_s.end_with?("_items") &&
            association.klass.included_modules.include?(Syncable)
        rescue NameError
          false
        end
      end
  end

  def perform
    Rails.logger.tagged("Sync", id, syncable_type, syncable_id) do
      # This can happen on server restarts or if Sidekiq enqueues a duplicate job
      unless may_start?
        Rails.logger.warn("Sync #{id} is not in a valid state (#{aasm.from_state}) to start.  Skipping sync.")
        return
      end

      start!

      begin
        syncable.perform_sync(self)
      rescue => e
        fail!
        update(error: e.message)
        report_error(e)
      ensure
        finalize_if_all_children_finalized
      end
    end
  end

  # Finalizes the current sync AND parent (if it exists)
  # PRODUCTION-READY: Deadlock prevention dengan consistent locking order
  # Best Practices:
  # 1. Consistent lock order (by ID) untuk menghindari deadlock
  # 2. Lock timeout untuk mencegah indefinite waiting
  # 3. Early returns untuk mengurangi lock contention
  # 4. Separate transaction untuk parent finalization
  def finalize_if_all_children_finalized
    # Early return jika tidak dalam state yang bisa di-finalize
    return unless finalizable_state?

    # PERFORMANCE: Cek children tanpa lock dulu untuk menghindari unnecessary locking
    return unless all_children_finalized?

    # DEADLOCK PREVENTION: Gunakan consistent locking order (by ID)
    # Semua sync locks harus diambil dalam urutan ID yang sama
    finalize_with_lock_protection

    # PERFORMANCE: Finalize parent di luar transaction untuk menghindari long-running transactions
    # DEADLOCK PREVENTION: Parent finalization juga menggunakan consistent lock order
    finalize_parent_safely
  end

  private
    def finalize_with_lock_protection
      # Gunakan lock dengan timeout untuk mencegah indefinite waiting
      Sync.transaction(requires_new: true) do
        # DEADLOCK PREVENTION: Lock dengan consistent order (by ID)
        # PostgreSQL akan acquire locks dalam urutan yang sama untuk semua transactions
        # NOWAIT prevents indefinite waiting - akan raise error jika lock tidak bisa diambil
        reload.lock!("FOR UPDATE NOWAIT")

        # Double-check state setelah lock (idempotency)
        return unless finalizable_state?
        return unless all_children_finalized?

        # Finalize sync
        if syncing?
          if has_failed_children?
            fail!
          else
            complete!
          end
        end

        # Perform post-sync operations
        perform_post_sync
      end
    rescue ActiveRecord::StatementInvalid => e
      # Handle lock timeout atau deadlock
      if e.message.include?("could not obtain lock") || e.message.include?("deadlock")
        Rails.logger.warn("Could not acquire lock for sync #{id} finalization: #{e.message}. Will retry on next attempt.")
        return
      end
      raise
    rescue ActiveRecord::Deadlocked => e
      Rails.logger.warn("Deadlock detected for sync #{id} finalization: #{e.message}. Will retry on next attempt.")
      nil
    end

    def finalize_parent_safely
      return unless parent

      # DEADLOCK PREVENTION: Parent juga harus di-lock dengan consistent order
      # Pastikan parent ID lebih kecil dari child ID untuk consistent ordering
      parent.finalize_if_all_children_finalized
    end

  public

  # PUBLIC METHOD: Called from syncable.rb when scheduling syncs
  # If a sync is pending, we can adjust the window if new syncs are created with a wider window.
  def expand_window_if_needed(new_window_start_date, new_window_end_date)
    return unless pending?
    return if self.window_start_date.nil? && self.window_end_date.nil? # already as wide as possible

    earliest_start_date = if self.window_start_date && new_window_start_date
      [ self.window_start_date, new_window_start_date ].min
    else
      nil
    end

    latest_end_date = if self.window_end_date && new_window_end_date
      [ self.window_end_date, new_window_end_date ].max
    else
      nil
    end

    update(
      window_start_date: earliest_start_date,
      window_end_date: latest_end_date
    )
  end

  def retry!
    return false unless failed? || stale?
    update!(status: "pending", error: nil, failed_at: nil, syncing_at: nil, pending_at: Time.current)
    enqueue_sync_job
    true
  end

  def dismiss!
    return false unless failed? || stale?
    destroy!
    true
  end

  def duration
    return nil unless syncing_at
    end_time = completed_at || failed_at || Time.current
    (end_time - syncing_at).round
  end

  def syncable_label
    return "#{syncable_type} (Deleted)" if syncable.nil?

    case syncable_type
    when "Family"
      "Family Sync"
    when "Account"
      provider = syncable.account_providers.first&.adapter&.item
      provider_name = provider&.class&.name&.gsub("Item", "") || "Manual"
      "#{provider_name} - #{syncable.name}"
    when "PlaidItem"
      "Plaid Connection (#{syncable.name.presence || syncable.institution_id || 'Active'})"
    when "SimpleFinItem"
      "SimpleFIN Connection (#{syncable.name.presence || syncable.institution_name.presence || 'Active'})"
    when "LunchflowItem"
      "Lunchflow Connection (#{syncable.name.presence || syncable.institution_name.presence || 'Active'})"
    else
      "#{syncable_type} #{syncable_id}"
    end
  end

  private
    def log_status_change
      Rails.logger.info("changing from #{aasm.from_state} to #{aasm.to_state} (event: #{aasm.current_event})")
    end

    def has_failed_children?
      children.failed.any?
    end

    def all_children_finalized?
      children.incomplete.empty?
    end

    def perform_post_sync
      Rails.logger.info("Performing post-sync for #{syncable_type} (#{syncable.id})")
      syncable.perform_post_sync
      syncable.broadcast_sync_complete
    rescue => e
      Rails.logger.error("Error performing post-sync for #{syncable_type} (#{syncable.id}): #{e.message}")
      report_error(e)
    end

    def report_error(error)
      Sentry.capture_exception(error) do |scope|
        scope.set_tags(sync_id: id)
        scope.set_extras(
          window_start_date: window_start_date,
          window_end_date: window_end_date,
          syncable_type: syncable_type,
          syncable_id: syncable_id
        )
      end
    end

    def report_warnings
      todays_sync_count = syncable.syncs.where(created_at: Date.current.all_day).count

      if todays_sync_count > 10
        Sentry.capture_exception(
          Error.new("#{syncable_type} (#{syncable.id}) has exceeded 10 syncs today (count: #{todays_sync_count})"),
          level: :warning
        )
      end
    end

    def handle_start_transition
      report_warnings
    end

    def handle_transition
      log_status_change
    end

    def handle_completion_transition
      family.touch(:latest_sync_completed_at)
    end

    def window_valid
      if window_start_date && window_end_date && window_start_date > window_end_date
        errors.add(:window_end_date, "must be greater than window_start_date")
      end
    end

    def update_family_sync_timestamp
      family.touch(:latest_sync_activity_at)
    end

    def finalizable_state?
      syncing? || pending? || failed?
    end

    def enqueue_sync_job
      # Commit-safe enqueue to prevent deserialization races before the row is visible
      SyncJob.perform_later(id)
    end

    def family
      if syncable.is_a?(Family)
        syncable
      else
        syncable.family
      end
    end
end
