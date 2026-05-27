class SimplefinItem::Syncer
  include SyncStats::Collector

  attr_reader :simplefin_item

  def initialize(simplefin_item)
    @simplefin_item = simplefin_item
  end

  def perform_sync(sync)
    unless Setting.simplefin_enabled
      raise "SimpleFIN sync is disabled in settings"
    end

    if sync.respond_to?(:sync_stats) && (sync.sync_stats || {})["balances_only"]
      sync.update!(status_text: "Refreshing balances only...") if sync.respond_to?(:status_text)
      mark_import_started(sync)
      SimplefinItem::Importer.new(
        simplefin_item,
        simplefin_provider: simplefin_item.simplefin_provider,
        sync: sync
      ).import_balances_only
      finalize_setup_counts(sync)
      return
    end

    linked_simplefin_accounts = simplefin_item.simplefin_accounts.select { |account| account.current_account.present? }
    if linked_simplefin_accounts.empty?
      sync.update!(status_text: "Discovering accounts (balances only)...") if sync.respond_to?(:status_text)
      mark_import_started(sync)
      SimplefinItem::Importer.new(
        simplefin_item,
        simplefin_provider: simplefin_item.simplefin_provider,
        sync: sync
      ).import_balances_only
      finalize_setup_counts(sync)
      return
    end

    # Phase 1: Import data from SimpleFin API
    sync.update!(status_text: "Importing accounts from SimpleFin...") if sync.respond_to?(:status_text)
    simplefin_item.import_latest_simplefin_data(sync: sync)

    finalize_setup_counts(sync)

    linked_simplefin_accounts = simplefin_item.simplefin_accounts.select { |account| account.current_account.present? }
    # Phase 2: Process transactions and holdings for linked accounts only
    if linked_simplefin_accounts.any?
      sync.update!(status_text: "Processing transactions and holdings...") if sync.respond_to?(:status_text)
      mark_import_started(sync)
      simplefin_item.process_accounts

      # Phase 3: Schedule balance calculations for linked accounts
      sync.update!(status_text: "Calculating balances...") if sync.respond_to?(:status_text)
      simplefin_item.schedule_account_syncs(
        parent_sync: sync,
        window_start_date: sync.window_start_date,
        window_end_date: sync.window_end_date
      )

      account_ids = linked_simplefin_accounts.filter_map { |account| account.current_account&.id }
      collect_transaction_stats(sync, account_ids: account_ids, source: "simplefin")

      holdings_count = linked_simplefin_accounts.sum { |account| Array(account.raw_holdings_payload).size }
      collect_holdings_stats(sync, holdings_count: holdings_count, label: "processed")
    end
  rescue => e
    if sync.respond_to?(:sync_stats) && (sync.sync_stats || {}).fetch("errors", []).blank?
      collect_health_stats(sync, errors: [ { message: e.message, category: "sync_error" } ])
    end
    raise
  end

  def perform_post_sync
    # no-op
  end

  private

    def finalize_setup_counts(sync)
      sync.update!(status_text: "Checking account configuration...") if sync.respond_to?(:status_text)
      collect_setup_stats(sync, provider_accounts: simplefin_item.simplefin_accounts)

      unlinked_accounts = simplefin_item.simplefin_accounts
        .left_joins(:account, :account_provider)
        .where(accounts: { id: nil }, account_providers: { id: nil })

      if unlinked_accounts.any?
        simplefin_item.update!(pending_account_setup: true)
        sync.update!(status_text: "#{unlinked_accounts.count} accounts need setup...") if sync.respond_to?(:status_text)
      else
        simplefin_item.update!(pending_account_setup: false)
      end
    end
end
