class FixNegativeSubscriptionRenewalEntries < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE entries
      SET amount = ABS(entries.amount),
          updated_at = CURRENT_TIMESTAMP
      FROM subscription_renewals
      WHERE subscription_renewals.entry_id = entries.id
        AND subscription_renewals.status = 'paid'
        AND entries.amount < 0
    SQL
  end

  def down
    # Positive expense magnitudes are the canonical representation.
  end
end
