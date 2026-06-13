class GoldPrice < ApplicationRecord
  SOURCES = %w[antam pegadaian harga_emas_org api manual].freeze
  METAL_TYPES = %w[gold].freeze

  validates :date, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :metal_type, presence: true, inclusion: { in: METAL_TYPES }
  validates :price_per_gram, presence: true, numericality: { greater_than: 0 }
  validates :buyback_price, numericality: { greater_than: 0 }, allow_nil: true
  validates :currency, presence: true, length: { is: 3 }
  validates :unit, presence: true
  validates :date, uniqueness: { scope: [ :source, :metal_type, :currency ] }

  scope :for_metal, ->(type) { where(metal_type: type) }
  scope :for_source, ->(source) { where(source: source) }
  scope :confirmed, -> { where(provisional: false) }
  scope :on_date, ->(date) { where(date: date) }
  scope :latest_first, -> { order(date: :desc) }

  # Fetch the latest confirmed price for a given metal type and source
  def self.latest_price(metal_type: "gold", source: nil, currency: "IDR")
    scope = confirmed.for_metal(metal_type).where(currency: currency).latest_first
    scope = scope.for_source(source) if source.present?
    scope.first
  end

  # Fetch price on a specific date, with fallback to the most recent prior date
  def self.price_on(date, metal_type: "gold", source: nil, currency: "IDR")
    scope = confirmed.for_metal(metal_type).where(currency: currency)
    scope = scope.for_source(source) if source.present?

    # Try exact date first, then fall back to most recent before that date
    scope.where("date <= ?", date).latest_first.first
  end

  # Bulk insert daily prices (upsert pattern for idempotency)
  def self.upsert_price(date:, source:, price_per_gram:, buyback_price: nil, metal_type: "gold", currency: "IDR", metadata: {})
    record = find_or_initialize_by(date: date, source: source, metal_type: metal_type, currency: currency)
    record.assign_attributes(
      price_per_gram: price_per_gram,
      buyback_price: buyback_price,
      provisional: false,
      metadata: metadata
    )
    record.save!
    record
  end

  def confirmed?
    !provisional?
  end

  def to_s
    "#{metal_type.capitalize} #{date}: #{currency} #{price_per_gram}/#{unit} (#{source})"
  end
end
