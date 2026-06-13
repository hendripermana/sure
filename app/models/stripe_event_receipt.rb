class StripeEventReceipt < ApplicationRecord
  belongs_to :subscription_plan, optional: true

  enum :status, {
    processed: "processed",
    ignored_stale: "ignored_stale"
  }

  validates :event_id, :event_type, :event_created_at, presence: true
  validates :event_id, uniqueness: true
end
