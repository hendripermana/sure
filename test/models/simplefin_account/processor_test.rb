require "test_helper"

class SimplefinAccount::ProcessorTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @simplefin_item = SimplefinItem.create!(
      family: @family,
      name: "Test SimpleFin Connection",
      access_url: "https://example.com/access_token"
    )
  end

  test "process_account! normalizes liability balances correctly" do
    credit_card = CreditCard.create!(subtype: "visa")

    account = Account.create!(
      family: @family,
      name: "Test Credit Card",
      balance: 0,
      accountable: credit_card,
      currency: "USD"
    )

    simplefin_account = SimplefinAccount.create!(
      simplefin_item: @simplefin_item,
      name: "Test Credit Card",
      account_id: "test_cc_123", # External ID
      currency: "USD",
      account_type: "credit",
      current_balance: -1500.00
    )

    # Pre-link explicitly as the processor likely relies on existing link or finding it
    account.update!(simplefin_account: simplefin_account)

    processor = SimplefinAccount::Processor.new(simplefin_account)
    processor.send(:process_account!)

    account.reload
    assert_equal 1500.00, account.balance, "Credit card balance should be normalized to positive"
  end

  test "process_account! keeps asset balances unchanged" do
    depository = Depository.create!(subtype: "checking")

    account = Account.create!(
      family: @family,
      name: "Test Checking",
      balance: 0,
      accountable: depository,
      currency: "USD"
    )

    simplefin_account = SimplefinAccount.create!(
      simplefin_item: @simplefin_item,
      name: "Test Checking",
      account_id: "test_checking_456",
      currency: "USD",
      account_type: "checking",
      current_balance: 2500.00
    )

    account.update!(simplefin_account: simplefin_account)

    processor = SimplefinAccount::Processor.new(simplefin_account)
    processor.send(:process_account!)

    account.reload
    assert_equal 2500.00, account.balance, "Checking account balance should remain unchanged"
  end

  test "process_account! handles loan liability normalization" do
    loan = Loan.create!(compliance_type: "conventional", lender_name: "Test Lender")

    account = Account.create!(
      family: @family,
      name: "Test Loan",
      balance: 0,
      accountable: loan,
      currency: "USD"
    )

    simplefin_account = SimplefinAccount.create!(
      simplefin_item: @simplefin_item,
      name: "Test Loan",
      account_id: "test_loan_789",
      currency: "USD",
      account_type: "loan",
      current_balance: -10000.00
    )

    account.update!(simplefin_account: simplefin_account)

    processor = SimplefinAccount::Processor.new(simplefin_account)
    processor.send(:process_account!)

    account.reload
    assert_equal 10000.00, account.balance, "Loan balance should be normalized to positive"
  end

  test "process_account! handles zero balance correctly" do
    credit_card = CreditCard.create!(subtype: "mastercard")

    account = Account.create!(
      family: @family,
      name: "Test Credit Card Zero",
      balance: 0,
      accountable: credit_card,
      currency: "USD"
    )

    simplefin_account = SimplefinAccount.create!(
      simplefin_item: @simplefin_item,
      name: "Test Credit Card Zero",
      account_id: "test_cc_zero",
      currency: "USD",
      account_type: "credit",
      current_balance: 0.00
    )

    account.update!(simplefin_account: simplefin_account)

    processor = SimplefinAccount::Processor.new(simplefin_account)
    processor.send(:process_account!)

    account.reload
    assert_equal 0.00, account.balance, "Zero balance should remain zero"
  end

  test "process_account! uses available_balance as fallback" do
    credit_card = CreditCard.create!(subtype: "visa")

    account = Account.create!(
      family: @family,
      name: "Test Credit Card Fallback",
      balance: 0,
      accountable: credit_card,
      currency: "USD"
    )

    # Note: validation requires either current or available balance.
    simplefin_account = SimplefinAccount.create!(
      simplefin_item: @simplefin_item,
      name: "Test Credit Card Fallback",
      account_id: "test_cc_fallback",
      currency: "USD",
      account_type: "credit",
      current_balance: nil,
      available_balance: -500.00
    )

    account.update!(simplefin_account: simplefin_account)

    processor = SimplefinAccount::Processor.new(simplefin_account)
    processor.send(:process_account!)

    account.reload
    assert_equal 500.00, account.balance, "Should use available_balance when current_balance is nil"
  end

  test "process_account! handles investment account cash balance" do
    investment = Investment.create!(subtype: "brokerage")

    account = Account.create!(
      family: @family,
      name: "Test Investment",
      balance: 0,
      accountable: investment,
      currency: "USD"
    )

    simplefin_account = SimplefinAccount.create!(
      simplefin_item: @simplefin_item,
      name: "Test Investment",
      account_id: "test_inv_123",
      currency: "USD",
      account_type: "investment",
      current_balance: 5000.00
    )

    account.update!(simplefin_account: simplefin_account)

    # Mock the balance calculator using mocha
    calculator = mock("BalanceCalculator")
    calculator.stubs(cash_balance: 1000.00)

    SimplefinAccount::Investments::BalanceCalculator.stubs(:new).returns(calculator)
    processor = SimplefinAccount::Processor.new(simplefin_account)
    processor.send(:process_account!)

    account.reload
    assert_equal 5000.00, account.balance, "Investment balance should be set"
  end

  test "process handles missing current_account gracefully" do
    # Here we typically expect it NOT to find an account.
    # But validation requires balance.
    simplefin_account = SimplefinAccount.create!(
      simplefin_item: @simplefin_item,
      name: "Test No Account",
      account_id: "test_no_acc",
      currency: "USD",
      account_type: "checking",
      current_balance: 100.00
    )

    processor = SimplefinAccount::Processor.new(simplefin_account)
    # Should not raise an error and should return early
    assert_nothing_raised do
      processor.process
    end
  end
end

class SimplefinAccount::BalanceNormalizationTest < ActiveSupport::TestCase
  test "balance normalization with various liability types" do
    family = families(:dylan_family)
    simplefin_item = SimplefinItem.create!(
      family: family,
      name: "Balance Norm Test",
      access_url: "https://example.com/token"
    )

    liability_types = [ "CreditCard", "Loan" ]

    liability_types.each do |liable_type|
      accountable = if liable_type == "Loan"
        Loan.create!(compliance_type: "conventional", lender_name: "Test Lender")
      else
        CreditCard.create!(subtype: "visa")
      end

      account = Account.create!(
        family: family,
        name: "Test #{liable_type}",
        balance: 0,
        accountable: accountable,
        currency: "USD"
      )

      simplefin_account = SimplefinAccount.create!(
        simplefin_item: simplefin_item,
        name: "Test #{liable_type}",
        account_id: "test_#{liable_type.downcase}_norm",
        currency: "USD",
        account_type: liable_type == "CreditCard" ? "credit" : "loan",
        current_balance: -2000.00
      )

      account.update!(simplefin_account: simplefin_account)

      processor = SimplefinAccount::Processor.new(simplefin_account)
      processor.send(:process_account!)

      account.reload
      assert_equal 2000.00, account.balance, "#{liable_type} balance should be normalized"
    end
  end

  test "asset types remain unchanged" do
    family = families(:dylan_family)
    simplefin_item = SimplefinItem.create!(
      family: family,
      name: "Asset Test",
      access_url: "https://example.com/token"
    )

    asset_types = [ "Depository", "Investment", "Crypto" ]

    asset_types.each do |asset_type|
      next if asset_type == "Crypto" && !defined?(Crypto)

      accountable = asset_type.constantize.create!(subtype: "generic")

      account = Account.create!(
        family: family,
        name: "Test #{asset_type}",
        balance: 0,
        accountable: accountable,
        currency: "USD"
      )

      account_type_map = {
        "Depository" => "checking",
        "Investment" => "investment",
        "Crypto" => "crypto"
      }

      simplefin_account = SimplefinAccount.create!(
        simplefin_item: simplefin_item,
        name: "Test #{asset_type}",
        account_id: "test_#{asset_type.downcase}_asset",
        currency: "USD",
        account_type: account_type_map[asset_type],
        current_balance: 3000.00
      )

      account.update!(simplefin_account: simplefin_account)

      processor = SimplefinAccount::Processor.new(simplefin_account)
      processor.send(:process_account!)

      account.reload
      assert_equal 3000.00, account.balance, "#{asset_type} balance should remain unchanged"
    end
  end
end
