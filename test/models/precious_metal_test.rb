require "test_helper"

class PreciousMetalTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:precious_metal)
    @precious_metal = @account.precious_metal
  end

  test "estimated value amount uses quantity and manual price" do
    expected = @precious_metal.quantity.to_d * @precious_metal.manual_price.to_d

    assert_equal expected, @precious_metal.estimated_value_amount
  end

  test "value_in converts to family currency when different" do
    @account.family.update!(currency: "IDR")
    @account.update!(currency: "USD")
    @precious_metal.update!(manual_price: 100, manual_price_currency: "USD", quantity: 2)

    ExchangeRate.expects(:find_or_fetch_rate).at_least_once.returns(Struct.new(:rate).new(15_000))

    value = @precious_metal.value_in
    estimated_value = @precious_metal.estimated_value_money

    assert_equal "IDR", value.currency.iso_code
    assert_equal "IDR", estimated_value.currency.iso_code
    assert_equal BigDecimal("3000000"), value.amount
  end

  test "value_in does not convert when target matches manual price currency" do
    @precious_metal.update!(manual_price_currency: "USD")

    ExchangeRate.expects(:find_or_fetch_rate).never

    value = @precious_metal.value_in("USD")

    assert_equal "USD", value.currency.iso_code
    assert_equal @precious_metal.estimated_value_amount, value.amount
  end

  test "value_in returns nil when FX rate is missing" do
    @account.family.update!(currency: "IDR")
    @account.update!(currency: "USD")
    @precious_metal.update!(manual_price: 100, manual_price_currency: "USD", quantity: 2)

    ExchangeRate.expects(:find_or_fetch_rate).returns(nil)

    assert_nil @precious_metal.value_in
  end

  test "value_in returns nil for unknown target currency" do
    assert_nil @precious_metal.value_in("ZZZ")
  end

  test "manual price optional returns nil estimated value" do
    @precious_metal.update!(manual_price: nil, manual_price_currency: nil)

    assert_nil @precious_metal.estimated_value_amount
    assert_nil @precious_metal.estimated_value_money
    assert_nil @precious_metal.value_in
  end

  test "supports 4-decimal quantity precision in valuation" do
    @precious_metal.update!(quantity: "0.2274", manual_price: 100, manual_price_currency: "USD")

    assert_equal BigDecimal("0.2274"), @precious_metal.quantity
    assert_equal BigDecimal("22.74"), @precious_metal.estimated_value_amount
  end

  test "validates manual price currency" do
    @precious_metal.manual_price_currency = "ZZZ"
    @precious_metal.valid?

    assert_includes @precious_metal.errors[:manual_price_currency], "is not a valid currency"
  end

  test "auto revaluation uses the configured market source" do
    @precious_metal.update!(
      auto_revalue: true,
      price_source: "antam",
      metal_type: "gold",
      manual_price_currency: "IDR"
    )
    GoldPrice.create!(
      date: Date.new(2026, 6, 7),
      source: "antam",
      price_per_gram: 2_888_000,
      currency: "IDR"
    )

    assert @precious_metal.apply_auto_revaluation!(as_of: Date.new(2026, 6, 7))
    assert_equal 2_888_000, @precious_metal.reload.manual_price
  end
end
