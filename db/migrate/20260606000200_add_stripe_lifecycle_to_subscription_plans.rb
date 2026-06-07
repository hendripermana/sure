class AddStripeLifecycleToSubscriptionPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :subscription_plans, :cancel_at_period_end, :boolean, default: false, null: false
    add_column :subscription_plans, :stripe_cancel_at, :datetime
    add_column :subscription_plans, :stripe_current_period_end, :datetime
    add_column :subscription_plans, :stripe_status, :string

    add_index :subscription_plans, :stripe_status
    add_index :subscription_plans, :cancel_at_period_end
  end
end
