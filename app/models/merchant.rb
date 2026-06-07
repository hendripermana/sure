class Merchant < ApplicationRecord
  TYPES = %w[FamilyMerchant ProviderMerchant ServiceMerchant].freeze

  has_many :transactions, dependent: :nullify
  has_many :recurring_transactions, dependent: :destroy
  has_many :recurring_transaction_suppressions, dependent: :nullify
  has_many :subscription_plans, dependent: :nullify

  validates :name, presence: true
  validates :type, inclusion: { in: TYPES }

  scope :alphabetically, -> { order(:name) }
  scope :with_logo, -> { where.not(logo_url: [ nil, "" ]) }
  scope :subscription_services, -> { where(type: "ServiceMerchant") }

  # Returns the best available logo URL for this merchant
  # Priority: 1) stored logo_url, 2) Brandfetch (if domain available), 3) nil
  def display_logo_url
    return logo_url if logo_url.present?
    brandfetch_logo_url
  end

  # Generate Brandfetch logo URL from website_url or name
  def brandfetch_logo_url
    return nil unless Setting.brand_fetch_client_id.present?

    domain = logo_domain
    return nil unless domain.present?

    "https://cdn.brandfetch.io/#{domain}/icon/fallback/lettermark/w/40/h/40?c=#{Setting.brand_fetch_client_id}"
  end

  # Fetch and persist logo from Brandfetch
  def fetch_and_save_logo!
    return if logo_url.present?

    url = brandfetch_logo_url
    update!(logo_url: url) if url.present?
  end

  private

    # Extract domain from website_url or attempt to derive from name
    def logo_domain
      if website_url.present?
        # Clean the URL to get just the domain
        uri = URI.parse(website_url.start_with?("http") ? website_url : "https://#{website_url}")
        uri.host&.gsub(/^www\./, "")
      else
        # Try to derive domain from name (e.g., "Netflix" -> "netflix.com")
        derived = name.downcase.gsub(/[^a-z0-9]/, "") + ".com"
        derived if derived.length > 4 # Only if reasonable
      end
    rescue URI::InvalidURIError
      nil
    end
end
