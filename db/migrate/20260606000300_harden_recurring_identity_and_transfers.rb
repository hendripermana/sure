require "digest"

class HardenRecurringIdentityAndTransfers < ActiveRecord::Migration[8.1]
  class MigrationRecurringTransaction < ActiveRecord::Base
    self.table_name = "recurring_transactions"
  end

  class MigrationRecurringSuppression < ActiveRecord::Base
    self.table_name = "recurring_transaction_suppressions"
  end

  def up
    add_recurring_transfer_and_identity
  end

  def down
    remove_check_constraint :recurring_transactions, name: "chk_recurring_txns_transfer_requires_source", if_exists: true
    remove_check_constraint :recurring_transactions, name: "chk_recurring_txns_transfer_distinct_accounts", if_exists: true
    remove_index :recurring_transactions, name: "idx_recurring_txns_identity", if_exists: true
    execute "DELETE FROM recurring_transactions WHERE destination_account_id IS NOT NULL"
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
    remove_column :recurring_transactions, :identity_signature, if_exists: true
    remove_reference :recurring_transactions, :destination_account, foreign_key: { to_table: :accounts }, if_exists: true

    MigrationRecurringSuppression.reset_column_information
    MigrationRecurringSuppression.find_each do |suppression|
      suppression.update_columns(signature: legacy_suppression_signature_for(suppression))
    end

    remove_reference :recurring_transaction_suppressions, :destination_account, foreign_key: { to_table: :accounts }, if_exists: true
  end

  private
    def add_recurring_transfer_and_identity
      unless column_exists?(:recurring_transactions, :destination_account_id)
        add_reference :recurring_transactions,
          :destination_account,
          type: :uuid,
          null: true,
          foreign_key: { to_table: :accounts, on_delete: :cascade }
      end

      unless column_exists?(:recurring_transaction_suppressions, :destination_account_id)
        add_reference :recurring_transaction_suppressions,
          :destination_account,
          type: :uuid,
          null: true,
          foreign_key: { to_table: :accounts, on_delete: :cascade }
      end

      MigrationRecurringSuppression.reset_column_information
      MigrationRecurringSuppression.find_each do |suppression|
        suppression.update_columns(signature: suppression_signature_for(suppression))
      end

      add_column :recurring_transactions, :identity_signature, :string unless column_exists?(:recurring_transactions, :identity_signature)

      MigrationRecurringTransaction.reset_column_information
      MigrationRecurringTransaction.find_each do |recurring|
        recurring.update_columns(identity_signature: recurring_identity_for(recurring))
      end

      deduplicate_recurring_identities

      change_column_null :recurring_transactions, :identity_signature, false
      remove_index :recurring_transactions, name: "idx_recurring_txns_acct_merchant", if_exists: true
      remove_index :recurring_transactions, name: "idx_recurring_txns_acct_name", if_exists: true
      add_index :recurring_transactions,
        [ :family_id, :identity_signature ],
        unique: true,
        name: "idx_recurring_txns_identity",
        if_not_exists: true

      add_check_constraint :recurring_transactions,
        "destination_account_id IS NULL OR account_id IS NOT NULL",
        name: "chk_recurring_txns_transfer_requires_source",
        if_not_exists: true

      add_check_constraint :recurring_transactions,
        "destination_account_id IS NULL OR destination_account_id <> account_id",
        name: "chk_recurring_txns_transfer_distinct_accounts",
        if_not_exists: true
    end

    def recurring_identity_for(recurring)
      normalized_name = recurring.name.to_s.squish.downcase
      normalized_amount = BigDecimal(recurring.amount.to_s).round(2).to_s("F")
      raw_identity = [
        "source:#{recurring.account_id || 'any'}",
        "destination:#{recurring.destination_account_id || 'none'}",
        "merchant:#{recurring.merchant_id || 'none'}",
        "name:#{normalized_name}",
        "amount:#{normalized_amount}",
        "currency:#{recurring.currency.to_s.upcase}"
      ].join("|")

      Digest::SHA256.hexdigest(raw_identity)
    end

    def suppression_signature_for(suppression)
      normalized_name = suppression.name.to_s.squish.downcase
      normalized_amount = BigDecimal(suppression.amount.to_s).round(2).to_s("F")

      [
        "account:#{suppression.account_id || 'any'}",
        "destination:#{suppression.destination_account_id || 'none'}",
        "merchant:#{suppression.merchant_id || 'none'}",
        "name:#{normalized_name}",
        "amount:#{normalized_amount}",
        "currency:#{suppression.currency}"
      ].join("|")
    end

    def legacy_suppression_signature_for(suppression)
      normalized_name = suppression.name.to_s.squish.downcase
      normalized_amount = BigDecimal(suppression.amount.to_s).round(2).to_s("F")

      [
        "account:#{suppression.account_id || 'any'}",
        "merchant:#{suppression.merchant_id || 'none'}",
        "name:#{normalized_name}",
        "amount:#{normalized_amount}",
        "currency:#{suppression.currency}"
      ].join("|")
    end

    def deduplicate_recurring_identities
      execute <<~SQL
        WITH ranked AS (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY family_id, identity_signature
                   ORDER BY manual DESC,
                            (status = 'active') DESC,
                            last_occurrence_date DESC NULLS LAST,
                            updated_at DESC,
                            id DESC
                 ) AS row_num
          FROM recurring_transactions
        )
        DELETE FROM recurring_transactions
        WHERE id IN (SELECT id FROM ranked WHERE row_num > 1)
      SQL
    end
end
