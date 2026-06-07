class CreateSubscriptionRenewals < ActiveRecord::Migration[8.1]
  def change
    create_table :subscription_renewals, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.uuid    :subscription_plan_id, null: false
      t.uuid    :account_id,           null: false
      t.uuid    :entry_id
      t.integer :cycle_number,         null: false, default: 1
      t.date    :billing_period_start, null: false
      t.date    :billing_period_end,   null: false
      t.date    :paid_at
      t.decimal :template_amount,      null: false, precision: 19, scale: 4
      t.decimal :actual_amount,        null: false, precision: 19, scale: 4
      t.decimal :admin_fee,            precision: 19, scale: 4, default: "0.0"
      t.virtual :total_paid,           type: :decimal, precision: 19, scale: 4,
                as: "actual_amount + COALESCE(admin_fee, 0)", stored: true
      t.string  :currency,             null: false, limit: 3
      t.string  :status,               null: false, default: "pending"
      t.string  :payment_method
      t.text    :notes
      t.jsonb   :metadata,             default: {}
      t.timestamps
    end

    add_foreign_key :subscription_renewals, :subscription_plans, on_delete: :cascade
    add_foreign_key :subscription_renewals, :accounts
    add_foreign_key :subscription_renewals, :entries, on_delete: :nullify

    add_index :subscription_renewals, :subscription_plan_id,
              name: "idx_sub_renewals_plan_id"
    add_index :subscription_renewals, :account_id,
              name: "idx_sub_renewals_account_id"
    add_index :subscription_renewals, :entry_id,
              name: "idx_sub_renewals_entry_id"
    add_index :subscription_renewals, [ :subscription_plan_id, :cycle_number ],
              unique: true,
              name: "idx_sub_renewals_plan_cycle_unique"
    add_index :subscription_renewals, [ :subscription_plan_id, :status ],
              name: "idx_sub_renewals_plan_status"
    add_index :subscription_renewals, :paid_at
  end
end
