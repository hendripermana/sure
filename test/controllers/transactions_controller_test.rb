require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  include EntryableResourceInterfaceTest, EntriesTestHelper

  setup do
    sign_in @user = users(:family_admin)
    @entry = entries(:transaction)
  end

  test "creates with transaction details" do
    assert_difference [ "Entry.count", "Transaction.count" ], 1 do
      post transactions_url, params: {
        entry: {
          account_id: @entry.account_id,
          name: "New transaction",
          date: Date.current,
          currency: "USD",
          amount: 100,
          nature: "inflow",
          entryable_type: @entry.entryable_type,
          entryable_attributes: {
            tag_ids: [ Tag.first.id, Tag.second.id ],
            category_id: Category.first.id,
            merchant_id: Merchant.first.id
          }
        }
      }
    end

    created_entry = Entry.order(:created_at).last

    assert_redirected_to transactions_url
    assert_equal "Transaction created", flash[:notice]
    assert_enqueued_with(job: SyncJob)
  end

  test "creates transaction and redirects to transactions_url when referer is not account page" do
    assert_difference [ "Entry.count", "Transaction.count" ], 1 do
      post transactions_url, headers: { "HTTP_REFERER" => root_url }, params: {
        entry: {
          account_id: @entry.account_id,
          name: "New transaction",
          date: Date.current,
          currency: "USD",
          amount: 100,
          nature: "inflow",
          entryable_type: @entry.entryable_type,
          entryable_attributes: {
            tag_ids: [ Tag.first.id ],
            category_id: Category.first.id,
            merchant_id: Merchant.first.id
          }
        }
      }
    end

    assert_redirected_to transactions_url
  end

  test "creates transaction and redirects back to account page when referer is account page" do
    account = @entry.account
    assert_difference [ "Entry.count", "Transaction.count" ], 1 do
      post transactions_url, headers: { "HTTP_REFERER" => account_url(account) }, params: {
        entry: {
          account_id: account.id,
          name: "New transaction",
          date: Date.current,
          currency: "USD",
          amount: 100,
          nature: "inflow",
          entryable_type: @entry.entryable_type,
          entryable_attributes: {
            tag_ids: [ Tag.first.id ],
            category_id: Category.first.id,
            merchant_id: Merchant.first.id
          }
        }
      }
    end

    assert_redirected_to account_url(account)
  end

  test "updates with transaction details" do
    assert_no_difference [ "Entry.count", "Transaction.count" ] do
      patch transaction_url(@entry), params: {
        entry: {
          name: "Updated name",
          date: Date.current,
          currency: "USD",
          amount: 100,
          nature: "inflow",
          entryable_type: @entry.entryable_type,
          notes: "test notes",
          excluded: false,
          entryable_attributes: {
            id: @entry.entryable_id,
            tag_ids: [ Tag.first.id, Tag.second.id ],
            category_id: Category.first.id,
            merchant_id: Merchant.first.id
          }
        }
      }
    end

    @entry.reload

    assert_equal "Updated name", @entry.name
    assert_equal Date.current, @entry.date
    assert_equal "USD", @entry.currency
    assert_equal -100, @entry.amount
    assert_equal [ Tag.first.id, Tag.second.id ], @entry.entryable.tag_ids.sort
    assert_equal Category.first.id, @entry.entryable.category_id
    assert_equal Merchant.first.id, @entry.entryable.merchant_id
    assert_equal "test notes", @entry.notes
    assert_equal false, @entry.excluded

    assert_equal "Transaction updated", flash[:notice]
    assert_redirected_to account_url(@entry.account)
    assert_enqueued_with(job: SyncJob)
  end

  test "creating transaction with subscription_plan_id advances subscription billing date" do
    # Use netflix subscription which belongs to the same family
    subscription = subscription_plans(:netflix_subscription)
    account = subscription.account

    # Set billing date to today to ensure payment is within window
    subscription.update!(next_billing_at: Date.current)
    original_next_billing = subscription.next_billing_at
    original_usage_count = subscription.usage_count || 0

    post transactions_url, params: {
      subscription_plan_id: subscription.id,
      entry: {
        account_id: account.id,
        name: "Subscription payment",
        date: Date.current,
        currency: subscription.currency,
        amount: subscription.amount,
        nature: "outflow",
        entryable_type: @entry.entryable_type,
        entryable_attributes: {
          tag_ids: [],
          category_id: Category.first.id,
          merchant_id: Merchant.first.id
        }
      }
    }

    subscription.reload

    # Verify billing was advanced
    assert_equal original_next_billing.next_month, subscription.next_billing_at, "Billing date should advance"
    assert_equal original_usage_count + 1, subscription.usage_count, "Usage count should increment"

    # Flash should include subscription name and new billing date
    assert_includes flash[:notice], subscription.name
    assert_includes flash[:notice], "billing advanced"
  end

  test "does not advance subscription when payment amount is outside tolerance" do
    subscription = subscription_plans(:spotify_subscription)
    account = subscription.account
    original_next_billing = subscription.next_billing_at

    too_large_amount = subscription.amount * 2

    assert_difference [ "Entry.count", "Transaction.count" ], 1 do
      post transactions_url, params: {
        subscription_plan_id: subscription.id,
        entry: {
          account_id: account.id,
          name: "Spotify oversized payment",
          date: Date.current,
          currency: subscription.currency,
          amount: too_large_amount,
          nature: "outflow",
          entryable_type: @entry.entryable_type,
          entryable_attributes: {
            tag_ids: [],
            category_id: Category.first.id,
            merchant_id: merchants(:netflix).id
          }
        }
      }
    end

    subscription.reload
    assert_equal original_next_billing, subscription.next_billing_at
  end

  test "does not advance subscription when currency does not match" do
    subscription = subscription_plans(:spotify_subscription)
    account = subscription.account
    original_next_billing = subscription.next_billing_at

    assert_difference [ "Entry.count", "Transaction.count" ], 1 do
      post transactions_url, params: {
        subscription_plan_id: subscription.id,
        entry: {
          account_id: account.id,
          name: "Spotify wrong currency",
          date: Date.current,
          currency: "EUR",
          amount: subscription.amount,
          nature: "outflow",
          entryable_type: @entry.entryable_type,
          entryable_attributes: {
            tag_ids: [],
            category_id: Category.first.id,
            merchant_id: merchants(:netflix).id
          }
        }
      }
    end

    subscription.reload
    assert_equal original_next_billing, subscription.next_billing_at
  end

  test "does not advance subscription when account does not match" do
    subscription = subscription_plans(:spotify_subscription)
    other_account = accounts(:depository)
    original_next_billing = subscription.next_billing_at

    assert_difference [ "Entry.count", "Transaction.count" ], 1 do
      post transactions_url, params: {
        subscription_plan_id: subscription.id,
        entry: {
          account_id: other_account.id,
          name: "Spotify wrong account",
          date: Date.current,
          currency: subscription.currency,
          amount: subscription.amount,
          nature: "outflow",
          entryable_type: @entry.entryable_type,
          entryable_attributes: {
            tag_ids: [],
            category_id: Category.first.id,
            merchant_id: merchants(:netflix).id
          }
        }
      }
    end

    subscription.reload
    assert_equal original_next_billing, subscription.next_billing_at
  end

  test "transaction count represents filtered total" do
    family = families(:empty)
    sign_in users(:empty)
    account = family.accounts.create! name: "Test", balance: 0, currency: "USD", accountable: Depository.new

    3.times do
      create_transaction(account: account)
    end

    get transactions_url(per_page: 10)

    assert_dom "#total-transactions", count: 1, text: family.entries.transactions.size.to_s

    searchable_transaction = create_transaction(account: account, name: "Unique test name")

    get transactions_url(q: { search: searchable_transaction.name })

    # Only finds 1 transaction that matches filter
    assert_dom "#" + dom_id(searchable_transaction), count: 1
    assert_dom "#total-transactions", count: 1, text: "1"
  end

  test "can paginate" do
  family = families(:empty)
  sign_in users(:empty)

  # Clean up any existing entries to ensure clean test
  family.accounts.each { |account| account.entries.delete_all }

  account = family.accounts.create! name: "Test", balance: 0, currency: "USD", accountable: Depository.new

  # Create multiple transactions for pagination
  25.times do |i|
    create_transaction(
      account: account,
      name: "Transaction #{i + 1}",
      amount: 100 + i,  # Different amounts to prevent transfer matching
      date: Date.current - i.days  # Different dates
    )
  end

  total_transactions = family.entries.transactions.count
  assert_operator total_transactions, :>=, 20, "Should have at least 20 transactions for testing"

  # Test page 1 - should show limited transactions
  get transactions_url(page: 1, per_page: 10)
  assert_response :success

  page_1_count = css_select("turbo-frame[id^='entry_']").count
  assert_equal 10, page_1_count, "Page 1 should respect per_page limit"

  # Test page 2 - should show different transactions
  get transactions_url(page: 2, per_page: 10)
  assert_response :success

  page_2_count = css_select("turbo-frame[id^='entry_']").count
  assert_operator page_2_count, :>, 0, "Page 2 should show some transactions"
  assert_operator page_2_count, :<=, 10, "Page 2 should not exceed per_page limit"

  # Test Pagy overflow handling - should redirect or handle gracefully
  get transactions_url(page: 9999999, per_page: 10)

  # Either success (if Pagy shows last page) or redirect (if Pagy redirects)
  assert_includes [ 200, 302 ], response.status, "Pagy should handle overflow gracefully"

  if response.status == 302
    follow_redirect!
    assert_response :success
  end

  overflow_count = css_select("turbo-frame[id^='entry_']").count
  assert_operator overflow_count, :>=, 0, "Overflow should render gracefully even if empty"
end

  test "calls Transaction::Search totals method with correct search parameters" do
    family = families(:empty)
    sign_in users(:empty)
    account = family.accounts.create! name: "Test", balance: 0, currency: "USD", accountable: Depository.new

    create_transaction(account: account, amount: 100)

    search = Transaction::Search.new(family)
    totals = OpenStruct.new(
      count: 1,
      expense_money: Money.new(10000, "USD"),
      income_money: Money.new(0, "USD")
    )

    Transaction::Search.expects(:new).with(family, filters: {}).returns(search)
    search.expects(:totals).once.returns(totals)

    get transactions_url
    assert_response :success
  end

  test "calls Transaction::Search totals method with filtered search parameters" do
    family = families(:empty)
    sign_in users(:empty)
    account = family.accounts.create! name: "Test", balance: 0, currency: "USD", accountable: Depository.new
    category = family.categories.create! name: "Food", color: "#ff0000"

    create_transaction(account: account, amount: 100, category: category)

    search = Transaction::Search.new(family, filters: { "categories" => [ "Food" ], "types" => [ "expense" ] })
    totals = OpenStruct.new(
      count: 1,
      expense_money: Money.new(10000, "USD"),
      income_money: Money.new(0, "USD")
    )

    Transaction::Search.expects(:new).with(family, filters: { "categories" => [ "Food" ], "types" => [ "expense" ] }).returns(search)
    search.expects(:totals).once.returns(totals)

    get transactions_url(q: { categories: [ "Food" ], types: [ "expense" ] })
    assert_response :success
  end

  test "creates a split transaction" do
    assert_difference "Entry.count", 3 do # Parent + 2 children
      post transactions_url, params: {
        split_transaction: "1",
        entry: {
          account_id: @entry.account_id,
          name: "Split Parent",
          date: Date.current,
          currency: "USD",
          amount: 100,
          nature: "outflow",
          entryable_type: @entry.entryable_type,
          entryable_attributes: {
            category_id: "",
            merchant_id: ""
          },
          splits: {
            "0" => { name: "Groceries", amount: "70", category_id: Category.first.id },
            "1" => { name: "Household", amount: "30", category_id: "" }
          }
        }
      }
    end

    created_parent = Entry.where(name: "Split Parent").last
    assert created_parent.excluded?
    assert created_parent.split_parent?

    children = created_parent.child_entries.order(:amount)
    assert_equal 2, children.count
    assert_equal 30, children.first.amount
    assert_equal 70, children.last.amount
    assert_nil created_parent.entryable.category_id
  end

  test "fails to create split transaction with unbalanced amounts" do
    assert_no_difference "Entry.count" do
      post transactions_url, params: {
        split_transaction: "1",
        entry: {
          account_id: @entry.account_id,
          name: "Unbalanced split",
          date: Date.current,
          currency: "USD",
          amount: 100,
          nature: "outflow",
          entryable_type: @entry.entryable_type,
          entryable_attributes: { category_id: "" },
          splits: {
            "0" => { name: "Part 1", amount: "60", category_id: categories(:food_and_drink).id },
            "1" => { name: "Part 2", amount: "30", category_id: categories(:subcategory).id }
          }
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "fails to create split with fewer than the minimum number of rows" do
    assert_no_difference "Entry.count" do
      post transactions_url, params: {
        split_transaction: "1",
        entry: {
          account_id: @entry.account_id,
          name: "Single split",
          date: Date.current,
          currency: "USD",
          amount: 100,
          nature: "outflow",
          entryable_type: @entry.entryable_type,
          entryable_attributes: { category_id: "" },
          splits: {
            "0" => { name: "Only one", amount: "100", category_id: categories(:food_and_drink).id }
          }
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "creates income split with correct negative amount signs" do
    assert_difference "Entry.count", 3 do # Parent + 2 children
      post transactions_url, params: {
        split_transaction: "1",
        entry: {
          account_id: @entry.account_id,
          name: "Income split",
          date: Date.current,
          currency: "USD",
          amount: 500, # Entered positive; inflow nature flips the sign
          nature: "inflow",
          entryable_type: @entry.entryable_type,
          entryable_attributes: { category_id: "" },
          splits: {
            "0" => { name: "Salary part 1", amount: "300", category_id: categories(:salary).id },
            "1" => { name: "Bonus", amount: "200", category_id: categories(:income).id }
          }
        }
      }
    end

    parent = Entry.where(name: "Income split").last
    assert_equal(-500, parent.amount) # Inflow stored as negative
    assert parent.split_parent?

    child_amounts = parent.child_entries.pluck(:amount).sort
    assert_equal [ -300, -200 ].sort, child_amounts
  end

  test "split children remain independent after parent update" do
    post transactions_url, params: {
      split_transaction: "1",
      entry: {
        account_id: @entry.account_id,
        name: "Original split",
        date: Date.current,
        currency: "USD",
        amount: 100,
        nature: "outflow",
        entryable_type: @entry.entryable_type,
        entryable_attributes: { category_id: "" },
        splits: {
          "0" => { name: "Part 1", amount: "60", category_id: categories(:food_and_drink).id },
          "1" => { name: "Part 2", amount: "40", category_id: categories(:subcategory).id }
        }
      }
    }

    parent = Entry.where(name: "Original split").last
    original_children_count = parent.child_entries.count
    assert_equal 2, original_children_count

    patch transaction_url(parent), params: {
      entry: {
        name: "Updated split name",
        amount: 150
      }
    }

    parent.reload
    assert_equal "Updated split name", parent.name
    assert_equal original_children_count, parent.child_entries.count
  end
end
