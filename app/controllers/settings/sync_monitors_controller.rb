class Settings::SyncMonitorsController < ApplicationController
  layout "settings"
  before_action :ensure_admin

  def show
    # Fetch the latest sync for each syncable target
    latest_syncs_query = Sync.for_family(Current.family)
                             .select("DISTINCT ON (syncable_type, syncable_id) syncs.*")
                             .order("syncable_type, syncable_id, created_at DESC")
                             .includes(:syncable)

    # Sort them in memory by created_at descending so the most recent overall is at the top
    @syncs = latest_syncs_query.to_a.sort_by { |s| s.created_at }.reverse

    if params[:status].present? && params[:status] != "all"
      @syncs = @syncs.select { |s| s.status == params[:status] }
    end

    # Summary is now based on the LATEST status of each target, not historical counts
    @summary = {
      pending:   @syncs.count { |s| s.status == "pending" },
      syncing:   @syncs.count { |s| s.status == "syncing" },
      failed:    @syncs.count { |s| s.status == "failed" },
      stale:     @syncs.count { |s| s.status == "stale" },
      completed: @syncs.count { |s| s.status == "completed" && s.created_at > 24.hours.ago }
    }
  end

  def retry_sync
    sync = Sync.for_family(Current.family).find(params[:id])
    if sync.retry!
      redirect_to settings_sync_monitor_path, notice: "Sync re-queued successfully."
    else
      redirect_to settings_sync_monitor_path, alert: "Sync cannot be retried in its current state."
    end
  end

  def retry_all_failed
    failed_syncs = Sync.for_family(Current.family).where(status: "failed")
    count = failed_syncs.count
    if count > 0
      failed_syncs.find_each(&:retry!)
      redirect_to settings_sync_monitor_path, notice: "Successfully re-queued #{count} failed syncs."
    else
      redirect_to settings_sync_monitor_path, alert: "No failed syncs found to retry."
    end
  end

  def dismiss_sync
    sync = Sync.for_family(Current.family).find(params[:id])
    if sync.dismiss!
      redirect_to settings_sync_monitor_path, notice: "Sync dismissed."
    else
      redirect_to settings_sync_monitor_path, alert: "Sync cannot be dismissed in its current state."
    end
  end

  def dismiss_all_stale
    stale_or_failed = Sync.for_family(Current.family).where(status: %w[stale failed])
    count = stale_or_failed.count
    if count > 0
      stale_or_failed.destroy_all
      redirect_to settings_sync_monitor_path, notice: "Cleared #{count} stale/failed syncs."
    else
      redirect_to settings_sync_monitor_path, alert: "No stale or failed syncs to clear."
    end
  end

  def sync_all
    Current.family.sync_later
    redirect_to settings_sync_monitor_path, notice: "Full sync started for all accounts."
  end

  def sync_target
    syncable = nil

    if params[:id].present?
      sync = Sync.for_family(Current.family).find_by(id: params[:id])
      syncable = sync&.syncable
    elsif params[:syncable_key].present?
      type, id = params[:syncable_key].split(":")

      case type
      when "Family"
        syncable = Current.family if id == Current.family.id.to_s
      when "Account"
        syncable = Current.family.accounts.find_by(id: id)
      when "PlaidItem"
        syncable = Current.family.plaid_items.find_by(id: id)
      when "SimpleFinItem"
        syncable = Current.family.simplefin_items.find_by(id: id)
      when "LunchflowItem"
        syncable = Current.family.lunchflow_items.find_by(id: id)
      end
    end

    if syncable.present? && syncable.respond_to?(:sync_later)
      syncable.sync_later

      label = if syncable.is_a?(Family)
        "Family Sync"
      elsif syncable.is_a?(Account)
        provider = syncable.account_providers.first&.adapter&.item
        provider_name = provider&.class&.name&.gsub("Item", "") || "Manual"
        "#{provider_name} - #{syncable.name}"
      elsif syncable.respond_to?(:name) && syncable.name.present?
        "#{syncable.class.name.gsub('Item', '')} connection (#{syncable.name})"
      else
        "#{syncable.class.name.gsub('Item', '')} connection"
      end

      redirect_to settings_sync_monitor_path, notice: "Sync triggered for #{label}."
    else
      redirect_to settings_sync_monitor_path, alert: "Sync target not found, unauthorized, or cannot be synced."
    end
  end

  private

    def ensure_admin
      redirect_to root_path, alert: "Not authorized" unless Current.user.admin?
    end
end
