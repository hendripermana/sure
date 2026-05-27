require "test_helper"

class Settings::SyncMonitorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:family_admin)
    @member = users(:family_member)
    @family = @admin.family
    @account = accounts(:depository) # Belongs to dylan_family
    sign_in @admin
  end

  test "admin can view sync monitor page" do
    Sync.create!(syncable: @family, status: "completed")
    Sync.create!(syncable: @account, status: "failed", error: "Connection error")

    get settings_sync_monitor_path
    assert_response :success
    assert_select "turbo-frame#sync_monitor_frame"
  end

  test "non-admin is redirected from sync monitor page" do
    sign_in @member
    get settings_sync_monitor_path
    assert_redirected_to root_path
    follow_redirect!
    assert_equal "Not authorized", flash[:alert]
  end

  test "can retry a failed/stale sync" do
    sync = Sync.create!(syncable: @account, status: "failed", error: "Connection error")

    post retry_sync_settings_sync_monitor_path(id: sync.id)
    assert_redirected_to settings_sync_monitor_path
    assert_equal "Sync re-queued successfully.", flash[:notice]
    assert_equal "pending", sync.reload.status
  end

  test "cannot retry active/completed sync" do
    sync = Sync.create!(syncable: @account, status: "completed")

    post retry_sync_settings_sync_monitor_path(id: sync.id)
    assert_redirected_to settings_sync_monitor_path
    assert_equal "Sync cannot be retried in its current state.", flash[:alert]
    assert_equal "completed", sync.reload.status
  end

  test "can retry all failed syncs" do
    sync1 = Sync.create!(syncable: @account, status: "failed")
    sync2 = Sync.create!(syncable: @account, status: "failed")
    sync3 = Sync.create!(syncable: @account, status: "completed")

    post retry_all_failed_settings_sync_monitor_path
    assert_redirected_to settings_sync_monitor_path
    assert_equal "Successfully re-queued 2 failed syncs.", flash[:notice]
    assert_equal "pending", sync1.reload.status
    assert_equal "pending", sync2.reload.status
    assert_equal "completed", sync3.reload.status
  end

  test "cannot retry all failed syncs if none exist" do
    post retry_all_failed_settings_sync_monitor_path
    assert_redirected_to settings_sync_monitor_path
    assert_equal "No failed syncs found to retry.", flash[:alert]
  end

  test "can dismiss a failed/stale sync" do
    sync = Sync.create!(syncable: @account, status: "failed")

    assert_difference "Sync.count", -1 do
      post dismiss_sync_settings_sync_monitor_path(id: sync.id)
    end
    assert_redirected_to settings_sync_monitor_path
    assert_equal "Sync dismissed.", flash[:notice]
  end

  test "cannot dismiss an active/completed sync" do
    sync = Sync.create!(syncable: @account, status: "completed")

    assert_no_difference "Sync.count" do
      post dismiss_sync_settings_sync_monitor_path(id: sync.id)
    end
    assert_redirected_to settings_sync_monitor_path
    assert_equal "Sync cannot be dismissed in its current state.", flash[:alert]
  end

  test "can dismiss all stale and failed syncs" do
    sync1 = Sync.create!(syncable: @account, status: "stale")
    sync2 = Sync.create!(syncable: @account, status: "failed")
    sync3 = Sync.create!(syncable: @account, status: "completed")

    post dismiss_all_stale_settings_sync_monitor_path
    assert_redirected_to settings_sync_monitor_path
    assert_equal "Cleared 2 stale/failed syncs.", flash[:notice]

    assert_nil Sync.find_by(id: sync1.id)
    assert_nil Sync.find_by(id: sync2.id)
    assert_not_nil Sync.find_by(id: sync3.id)
  end

  test "cannot dismiss all stale and failed syncs if none exist" do
    post dismiss_all_stale_settings_sync_monitor_path
    assert_redirected_to settings_sync_monitor_path
    assert_equal "No stale or failed syncs to clear.", flash[:alert]
  end

  test "can trigger a full family sync" do
    Family.any_instance.expects(:sync_later).once

    post sync_all_settings_sync_monitor_path
    assert_redirected_to settings_sync_monitor_path
    assert_equal "Full sync started for all accounts.", flash[:notice]
  end

  test "can filter by status query parameter" do
    Sync.create!(syncable: @family, status: "completed")
    Sync.create!(syncable: @account, status: "failed")

    get settings_sync_monitor_path(status: "failed")
    assert_response :success
  end

  test "can trigger sync for a specific sync target by sync id" do
    sync = Sync.create!(syncable: @account, status: "completed")
    Account.any_instance.expects(:sync_later).once

    post sync_target_settings_sync_monitor_path(id: sync.id)
    assert_redirected_to settings_sync_monitor_path
    assert_match /Sync triggered for/, flash[:notice]
  end

  test "can trigger sync for a specific sync target by syncable_key" do
    Account.any_instance.expects(:sync_later).once

    post sync_target_settings_sync_monitor_path(syncable_key: "Account:#{@account.id}")
    assert_redirected_to settings_sync_monitor_path
    assert_match /Sync triggered for/, flash[:notice]
  end

  test "cannot sync an account belonging to a different family" do
    other_family = families(:empty)
    other_account = Account.create!(
      name: "Other Account",
      family: other_family,
      currency: "USD",
      balance: 100,
      accountable: depositories(:one)
    )

    post sync_target_settings_sync_monitor_path(syncable_key: "Account:#{other_account.id}")
    assert_redirected_to settings_sync_monitor_path
    assert_equal "Sync target not found, unauthorized, or cannot be synced.", flash[:alert]
  end
end
