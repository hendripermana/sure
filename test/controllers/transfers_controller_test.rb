require "test_helper"

class TransfersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "should get new" do
    get new_transfer_url
    assert_response :success
  end

  test "can create transfers" do
    assert_difference "Transfer.count", 1 do
      post transfers_url, params: {
        transfer: {
          from_account_id: accounts(:depository).id,
          to_account_id: accounts(:credit_card).id,
          date: Date.current,
          amount: 100,
          name: "Test Transfer"
        }
      }
      assert_enqueued_with job: SyncJob
    end
  end

  test "can create transfer to precious metals" do
    metal_account = accounts(:precious_metal)
    starting_quantity = metal_account.precious_metal.quantity.to_d

    assert_difference "Transfer.count", 1 do
      post transfers_url, params: {
        transfer: {
          from_account_id: accounts(:depository).id,
          to_account_id: metal_account.id,
          date: Date.current,
          amount: 151,
          price_per_unit: 75.5,
          price_currency: "USD"
        }
      }
    end

    metal_account.reload
    assert_equal starting_quantity + 2.to_d, metal_account.precious_metal.quantity

    transfer = Transfer.order(:created_at).last
    assert_equal "buy", transfer.inflow_transaction.precious_metal_action
  end

  test "soft deletes transfer" do
    assert_difference -> { Transfer.count }, -1 do
      delete transfer_url(transfers(:one))
    end
  end

  test "can add notes to transfer" do
    transfer = transfers(:one)
    assert_nil transfer.notes

    patch transfer_url(transfer), params: { transfer: { notes: "Test notes" } }

    assert_redirected_to transactions_url
    assert_equal "Transfer updated", flash[:notice]
    assert_equal "Test notes", transfer.reload.notes
  end

  test "handles rejection without FrozenError" do
    transfer = transfers(:one)

    assert_difference "Transfer.count", -1 do
      patch transfer_url(transfer), params: {
        transfer: {
          status: "rejected"
        }
      }
    end

    assert_redirected_to transactions_url
    assert_equal "Transfer updated", flash[:notice]

    # Verify the transfer was actually destroyed
    assert_raises(ActiveRecord::RecordNotFound) do
      transfer.reload
    end
  end

  test "marks a transfer as recurring" do
    transfer = transfers(:one)

    assert_difference "RecurringTransaction.count", 1 do
      post mark_as_recurring_transfer_url(transfer)
    end

    recurring = RecurringTransaction.order(:created_at).last
    assert_redirected_to recurring_transactions_path
    assert_equal transfer.from_account, recurring.account
    assert_equal transfer.to_account, recurring.destination_account
  end

  test "show exposes recurring transfer action" do
    transfer = transfers(:one)

    get transfer_url(transfer)

    assert_response :success
    assert_select "form[action='#{mark_as_recurring_transfer_path(transfer)}']" do
      assert_select "button", text: /Mark recurring/
    end
  end

  test "does not create the same recurring transfer twice" do
    transfer = transfers(:one)
    RecurringTransaction.create_from_transfer(transfer)

    assert_no_difference "RecurringTransaction.count" do
      post mark_as_recurring_transfer_url(transfer)
    end

    assert_redirected_to transactions_path
    assert_equal "This recurring transfer already exists or is invalid.", flash[:alert]
  end
end
