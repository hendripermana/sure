class AddFlexibleBillingToSubscriptionPlans < ActiveRecord::Migration[8.1]
  def change
    change_table :subscription_plans do |t|
      t.integer  :billing_day_start
      t.integer  :billing_day_end
      t.decimal  :default_admin_fee, precision: 19, scale: 4, default: "0.0"
      t.datetime :discarded_at
    end

    add_index :subscription_plans, :discarded_at,
              name: "idx_sub_plans_discarded_at"
    add_index :subscription_plans, [ :billing_day_start, :billing_day_end ],
              name: "idx_sub_plans_billing_window"
  end
end
