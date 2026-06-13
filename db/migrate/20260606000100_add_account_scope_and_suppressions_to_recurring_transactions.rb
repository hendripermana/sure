class AddAccountScopeAndSuppressionsToRecurringTransactions < ActiveRecord::Migration[8.1]
  def up
    add_account_scope_to_recurring_transactions
    create_recurring_transaction_suppressions
  end

  def down
    drop_table :recurring_transaction_suppressions, if_exists: true

    remove_index :recurring_transactions, name: "idx_recurring_txns_acct_merchant", if_exists: true
    remove_index :recurring_transactions, name: "idx_recurring_txns_acct_name", if_exists: true

    add_index :recurring_transactions,
      [ :family_id, :merchant_id, :amount, :currency ],
      unique: true,
      name: "idx_recurring_txns_on_family_merchant_amount_currency",
      if_not_exists: true

    remove_reference :recurring_transactions, :account, foreign_key: true, if_exists: true
  end

  private

    def add_account_scope_to_recurring_transactions
      unless column_exists?(:recurring_transactions, :account_id)
        add_reference :recurring_transactions,
          :account,
          type: :uuid,
          null: true,
          foreign_key: { to_table: :accounts, on_delete: :cascade }
      end

      backfill_recurring_transaction_accounts

      dedupe_recurring_transactions!(
        partition_columns: %w[family_id account_id merchant_id amount currency],
        where_clause: "account_id IS NOT NULL AND merchant_id IS NOT NULL"
      )

      dedupe_recurring_transactions!(
        partition_columns: %w[family_id account_id name amount currency],
        where_clause: "account_id IS NOT NULL AND merchant_id IS NULL AND name IS NOT NULL"
      )

      remove_index :recurring_transactions,
        name: "idx_recurring_txns_on_family_merchant_amount_currency",
        if_exists: true

      add_index :recurring_transactions,
        [ :family_id, :account_id, :merchant_id, :amount, :currency ],
        unique: true,
        where: "account_id IS NOT NULL AND merchant_id IS NOT NULL",
        name: "idx_recurring_txns_acct_merchant",
        if_not_exists: true

      add_index :recurring_transactions,
        [ :family_id, :account_id, :name, :amount, :currency ],
        unique: true,
        where: "account_id IS NOT NULL AND merchant_id IS NULL AND name IS NOT NULL",
        name: "idx_recurring_txns_acct_name",
        if_not_exists: true
    end

    def backfill_recurring_transaction_accounts
      execute <<~SQL
        UPDATE recurring_transactions rt
        SET account_id = matches.account_id
        FROM (
          SELECT DISTINCT ON (rt2.id)
            rt2.id AS recurring_transaction_id,
            entries.account_id
          FROM recurring_transactions rt2
          JOIN entries
            ON entries.entryable_type = 'Transaction'
           AND entries.currency = rt2.currency
           AND entries.amount = rt2.amount
           AND EXTRACT(DAY FROM entries.date)
             BETWEEN GREATEST(rt2.expected_day_of_month - 2, 1)
                 AND LEAST(rt2.expected_day_of_month + 2, 31)
          JOIN accounts
            ON accounts.id = entries.account_id
           AND accounts.family_id = rt2.family_id
          LEFT JOIN transactions
            ON transactions.id = entries.entryable_id
          WHERE rt2.account_id IS NULL
            AND (
              (rt2.merchant_id IS NOT NULL AND transactions.merchant_id = rt2.merchant_id)
              OR (rt2.merchant_id IS NULL AND entries.name = rt2.name)
            )
          ORDER BY rt2.id, entries.date DESC
        ) matches
        WHERE rt.id = matches.recurring_transaction_id
      SQL
    end

    def create_recurring_transaction_suppressions
      return if table_exists?(:recurring_transaction_suppressions)

      create_table :recurring_transaction_suppressions, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
        t.references :family, null: false, foreign_key: { on_delete: :cascade }, type: :uuid
        t.references :account, foreign_key: { on_delete: :cascade }, type: :uuid
        t.references :merchant, foreign_key: { on_delete: :nullify }, type: :uuid
        t.string :name
        t.decimal :amount, precision: 19, scale: 4, null: false
        t.string :currency, null: false
        t.integer :expected_day_of_month
        t.string :signature, null: false
        t.string :reason, null: false, default: "user_ignored"
        t.jsonb :metadata, default: {}, null: false
        t.timestamps
      end

      add_index :recurring_transaction_suppressions,
        [ :family_id, :signature ],
        unique: true,
        name: "idx_recurring_txn_suppressions_unique"
    end

    def dedupe_recurring_transactions!(partition_columns:, where_clause:)
      execute <<~SQL
        WITH ranked AS (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY #{partition_columns.join(', ')}
                   ORDER BY manual DESC,
                            (status = 'active') DESC,
                            last_occurrence_date DESC NULLS LAST,
                            updated_at DESC,
                            id DESC
                 ) AS row_num
          FROM recurring_transactions
          WHERE #{where_clause}
        )
        DELETE FROM recurring_transactions
        WHERE id IN (
          SELECT id FROM ranked WHERE row_num > 1
        )
      SQL
    end
end
