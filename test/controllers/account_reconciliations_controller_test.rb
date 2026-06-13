require "test_helper"

class AccountReconciliationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository) # Manual depository account
  end

  test "should get new" do
    get new_account_reconciliation_path(@account)
    assert_response :success
    assert_select "p", text: /App Balance for Checking Account/
  end

  test "should compare balances on create" do
    post account_reconciliation_path(@account), params: {
      reconciliation: {
        real_balance: "5500.00",
        date: Date.current.to_s
      }
    }
    assert_response :success
    assert_select "h3", text: "Balance Mismatch Found"
    assert_select "p", text: /-\$500/
  end

  test "should apply reconciliation when apply is true" do
    assert_difference "Entry.count", 1 do
      post account_reconciliation_path(@account), params: {
        reconciliation: {
          real_balance: "5500.00",
          date: Date.current.to_s,
          apply: "true"
        }
      }
    end

    assert_redirected_to account_path(@account)
    follow_redirect!
    assert_select "div", text: /Balance reconciled to \$5,500.00/
  end

  test "should show synced message when balances match" do
    post account_reconciliation_path(@account), params: {
      reconciliation: {
        real_balance: "5000.00", # Matches fixture balance of 5000
        date: Date.current.to_s
      }
    }
    assert_response :success
    assert_select "h3", text: "Balance is Synced! ✅"
  end
end
