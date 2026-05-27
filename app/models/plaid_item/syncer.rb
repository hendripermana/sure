class PlaidItem::Syncer
  include SyncStats::Collector

  attr_reader :plaid_item

  def initialize(plaid_item)
    @plaid_item = plaid_item
  end

  def perform_sync(sync)
    unless Setting.plaid_enabled
      raise "Plaid sync is disabled in settings"
    end

    # Phase 1: Import data from Plaid API
    sync.update!(status_text: "Importing accounts from Plaid...") if sync.respond_to?(:status_text)
    plaid_item.import_latest_plaid_data

    # Phase 2: Collect setup statistics
    sync.update!(status_text: "Checking account configuration...") if sync.respond_to?(:status_text)
    collect_setup_stats(sync, provider_accounts: plaid_item.plaid_accounts)

    linked_accounts = plaid_item.plaid_accounts.select { |account| account.current_account.present? }
    if linked_accounts.any?
      # Phase 3: Process the raw Plaid data and updates internal domain objects
      sync.update!(status_text: "Processing transactions...") if sync.respond_to?(:status_text)
      mark_import_started(sync)
      plaid_item.process_accounts

      # Phase 4: Schedule balance calculations
      sync.update!(status_text: "Calculating balances...") if sync.respond_to?(:status_text)
      plaid_item.schedule_account_syncs(
        parent_sync: sync,
        window_start_date: sync.window_start_date,
        window_end_date: sync.window_end_date
      )

      # Phase 5: Collect transaction and holdings statistics
      account_ids = linked_accounts.filter_map { |account| account.current_account&.id }
      collect_transaction_stats(sync, account_ids: account_ids, source: "plaid")
      collect_holdings_stats(sync, holdings_count: count_holdings(linked_accounts), label: "processed")
    end

    collect_health_stats(sync, errors: nil)
  rescue => e
    collect_health_stats(sync, errors: [ { message: e.message, category: "sync_error" } ])
    raise
  end

  def perform_post_sync
    # no-op
  end

  private

    def count_holdings(plaid_accounts)
      plaid_accounts.sum do |account|
        Array(account.raw_investments_payload).size
      end
    end
end
