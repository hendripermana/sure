class AddStripeEventTracking < ActiveRecord::Migration[8.1]
  def change
    add_column :subscription_plans, :stripe_last_event_created_at, :datetime
    add_column :subscription_plans, :stripe_last_event_id, :string

    create_table :stripe_event_receipts, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :subscription_plan, type: :uuid, foreign_key: { on_delete: :cascade }
      t.string :event_id, null: false
      t.string :event_type, null: false
      t.datetime :event_created_at, null: false
      t.string :status, null: false, default: "processed"
      t.timestamps
    end

    add_index :stripe_event_receipts, :event_id, unique: true
    add_index :stripe_event_receipts, [ :subscription_plan_id, :event_created_at ],
      name: "idx_stripe_receipts_plan_created"
  end
end
