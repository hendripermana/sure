class RecurringTransactionSuppression < ApplicationRecord
  belongs_to :family
  belongs_to :account, optional: true
  belongs_to :destination_account, optional: true, class_name: "Account"
  belongs_to :merchant, optional: true

  validates :amount, presence: true
  validates :currency, presence: true
  validates :signature, presence: true, uniqueness: { scope: :family_id }
  validate :merchant_or_name_present

  before_validation :assign_signature

  def self.signature_for(account_id:, destination_account_id: nil, merchant_id:, name:, amount:, currency:)
    return nil if amount.blank? || currency.blank?

    normalized_name = name.to_s.squish.downcase
    normalized_amount = BigDecimal(amount.to_s).round(2).to_s("F")

    [
      "account:#{account_id || 'any'}",
      "destination:#{destination_account_id || 'none'}",
      "merchant:#{merchant_id || 'none'}",
      "name:#{normalized_name}",
      "amount:#{normalized_amount}",
      "currency:#{currency}"
    ].join("|")
  end

  def self.suppressed?(family:, account_id:, destination_account_id: nil, merchant_id:, name:, amount:, currency:)
    signature = signature_for(
      account_id: account_id,
      destination_account_id: destination_account_id,
      merchant_id: merchant_id,
      name: name,
      amount: amount,
      currency: currency
    )

    legacy_signature = signature_for(
      account_id: nil,
      destination_account_id: destination_account_id,
      merchant_id: merchant_id,
      name: name,
      amount: amount,
      currency: currency
    )

    where(family: family, signature: [ signature, legacy_signature ]).exists?
  end

  def self.suppress!(family:, account_id:, destination_account_id: nil, merchant_id:, name:, amount:, currency:, expected_day_of_month: nil, reason: "user_ignored", metadata: {})
    signature = signature_for(
      account_id: account_id,
      destination_account_id: destination_account_id,
      merchant_id: merchant_id,
      name: name,
      amount: amount,
      currency: currency
    )

    create_with(
      account_id: account_id,
      destination_account_id: destination_account_id,
      merchant_id: merchant_id,
      name: name,
      amount: amount,
      currency: currency,
      expected_day_of_month: expected_day_of_month,
      reason: reason,
      metadata: metadata
    ).find_or_create_by!(family: family, signature: signature)
  end

  private

    def assign_signature
      return if amount.blank? || currency.blank?

      self.signature ||= self.class.signature_for(
        account_id: account_id,
        destination_account_id: destination_account_id,
        merchant_id: merchant_id,
        name: name,
        amount: amount,
        currency: currency
      )
    end

    def merchant_or_name_present
      return if merchant_id.present? || name.present?

      errors.add(:base, "Either merchant or name must be present")
    end
end
