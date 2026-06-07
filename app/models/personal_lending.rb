class PersonalLending < ApplicationRecord
  include Accountable

  LENDING_DIRECTIONS = {
    "lending_out" => { short: "Lending Out", long: "Money Lent to Others" }
  }.freeze

  LENDING_TYPES = {
    "qard_hasan" => { short: "Qard Hasan", long: "Islamic Interest-Free Loan" },
    "interest_free" => { short: "Interest-Free", long: "Interest-Free Personal Loan" },
    "informal_with_agreement" => { short: "With Agreement", long: "Informal Loan with Written Agreement" },
    "informal" => { short: "Informal", long: "Informal Personal Loan" }
  }.freeze

  RELATIONSHIPS = {
    "family" => { short: "Family", long: "Family Member" },
    "friend" => { short: "Friend", long: "Friend" },
    "colleague" => { short: "Colleague", long: "Work Colleague" },
    "business_partner" => { short: "Business", long: "Business Partner" },
    "neighbor" => { short: "Neighbor", long: "Neighbor" },
    "other" => { short: "Other", long: "Other" }
  }.freeze

  REMINDER_FREQUENCIES = {
    "none" => { short: "None", long: "No Reminders" },
    "before_due" => { short: "Before Due", long: "Before Due Date" },
    "weekly" => { short: "Weekly", long: "Weekly Reminders" },
    "monthly" => { short: "Monthly", long: "Monthly Reminders" }
  }.freeze

  # Define SUBTYPES to match other accountable types
  # For PersonalLending, subtype is based on lending_type
  SUBTYPES = {
    "qard_hasan" => { short: "Qard Hasan", long: "Islamic Interest-Free Loan" },
    "interest_free" => { short: "Interest-Free", long: "Interest-Free Personal Loan" },
    "informal_with_agreement" => { short: "With Agreement", long: "Informal Loan with Written Agreement" },
    "informal" => { short: "Informal", long: "Informal Personal Loan" }
  }.freeze

  # Validations following Sure app patterns
  validates :counterparty_name, presence: true, length: { maximum: 255 }
  validates :lending_direction, inclusion: { in: LENDING_DIRECTIONS.keys }
  validates :lending_type, inclusion: { in: LENDING_TYPES.keys }
  validates :relationship, inclusion: { in: RELATIONSHIPS.keys }, allow_nil: true
  validates :reminder_frequency, inclusion: { in: REMINDER_FREQUENCIES.keys }, allow_nil: true
  validates :initial_amount, presence: true, numericality: { greater_than: 0 }
  validates :expected_return_date, presence: true

  # Custom validation: disallow past dates (today is allowed)
  validate :expected_return_date_is_future, on: :create
  before_validation :set_default_lending_direction, on: :create

  class << self
    def display_name
      "Personal Lending"
    end
    def color
      "#8B5CF6" # Purple color for personal lending
    end

    def icon
      "handshake" # Handshake icon representing personal agreements
    end

    def classification
      # Treated as an asset in account listings since it represents
      # money you have lent out to someone (receivable).
      "asset"
    end
  end

  # For UI consistency in selectors and lists, we keep a stable
  # label. Account naming and direction-specific labels can be
  # handled elsewhere.
  def display_name
    self.class.display_name
  end

  # Check if this is a Sharia-compliant loan
  def sharia_compliant?
    lending_type.in?(%w[qard_hasan interest_free])
  end

  # Check if loan is overdue
  def overdue?
    return false unless expected_return_date
    return false if actual_return_date # Already returned

    Date.current > expected_return_date
  end

  # Days until due (negative if overdue)
  def days_until_due
    return nil unless expected_return_date
    return 0 if actual_return_date # Already returned

    (expected_return_date - Date.current).to_i
  end

  # Human-readable status
  def status
    # Consider it returned when actual_return_date is set, or when balance is zero
    return "returned" if actual_return_date || account&.balance.to_d <= 0
    return "overdue" if overdue?
    return "due_soon" if days_until_due && days_until_due <= 7

    "active"
  end

  # Direction/counterparty-specific naming can be shown in views if needed,
  # but `display_name` stays stable for selectors and grouping.

  private
    def set_default_lending_direction
      # Force to lending_out to avoid legacy direction in new records
      self.lending_direction = "lending_out"
    end

    def expected_return_date_is_future
      return unless expected_return_date

      if expected_return_date < Date.current
        errors.add(:expected_return_date, "cannot be in the past")
      end
    end
end
