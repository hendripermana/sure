require "test_helper"

class GoldPriceFetcherTest < ActiveSupport::TestCase
  HTML = <<~HTML
    <html>
      <body>
        <table>
          <thead>
            <tr><th>Gram</th><th>Antam</th><th>Pegadaian</th></tr>
          </thead>
          <tbody>
            <tr><td>2</td><td>5.416.000</td><td>5.412.000</td></tr>
            <tr><td>1</td><td>2.888.000</td><td>2.739.000</td></tr>
          </tbody>
        </table>
        <span>Harga pembelian kembali: Rp2.599.200 /grm</span>
      </body>
    </html>
  HTML

  test "stores the Antam one gram and buyback prices" do
    fetcher = GoldPriceFetcher.new
    fetcher.stubs(:fetch_html).returns(HTML)

    result = fetcher.fetch(date: Date.new(2026, 6, 7))
    price = GoldPrice.find_by!(date: Date.new(2026, 6, 7), source: "antam")

    assert result.success?
    assert_equal 2_888_000, price.price_per_gram
    assert_equal 2_599_200, price.buyback_price
    assert_equal "harga_emas_org", price.metadata.fetch("provider")
  end

  test "returns a failed result when the provider markup cannot be parsed" do
    fetcher = GoldPriceFetcher.new
    fetcher.stubs(:fetch_html).returns("<html><body>no price table</body></html>")

    result = fetcher.fetch(date: Date.new(2026, 6, 7))

    assert_not result.success?
    assert_match(/Antam price table/, result.error)
  end

  test "allows transient network failures to reach the job retry handler" do
    fetcher = GoldPriceFetcher.new
    fetcher.stubs(:fetch_html).raises(Net::ReadTimeout)

    assert_raises(Net::ReadTimeout) do
      fetcher.fetch(date: Date.new(2026, 6, 7))
    end
  end
end
