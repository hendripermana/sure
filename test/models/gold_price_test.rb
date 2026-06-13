require "test_helper"

class GoldPriceTest < ActiveSupport::TestCase
  test "price_on falls back to the latest confirmed prior price" do
    GoldPrice.create!(
      date: Date.new(2026, 6, 5),
      source: "antam",
      price_per_gram: 2_800_000,
      currency: "IDR"
    )
    GoldPrice.create!(
      date: Date.new(2026, 6, 6),
      source: "antam",
      price_per_gram: 2_850_000,
      currency: "IDR",
      provisional: true
    )

    price = GoldPrice.price_on(Date.new(2026, 6, 7), source: "antam", currency: "IDR")

    assert_equal Date.new(2026, 6, 5), price.date
    assert_equal 2_800_000, price.price_per_gram
  end

  test "upsert_price is idempotent for a daily source price" do
    attributes = {
      date: Date.new(2026, 6, 7),
      source: "antam",
      price_per_gram: 2_888_000,
      buyback_price: 2_599_200
    }

    assert_difference "GoldPrice.count", 1 do
      GoldPrice.upsert_price(**attributes)
      GoldPrice.upsert_price(**attributes.merge(price_per_gram: 2_900_000))
    end

    assert_equal 2_900_000, GoldPrice.find_by!(date: attributes[:date], source: "antam").price_per_gram
  end
end
