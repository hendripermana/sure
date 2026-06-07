class AuditLog < ApplicationRecord
  belongs_to :auditable, polymorphic: true
  belongs_to :user, optional: true

  scope :reverse_chronological, -> { order(created_at: :desc) }
  scope :recurring_events, -> { where("event LIKE ?", "recurring.%") }
end
