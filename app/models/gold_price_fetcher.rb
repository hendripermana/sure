require "net/http"
require "nokogiri"

class GoldPriceFetcher
  class ParseError < StandardError; end
  class TransientError < StandardError; end

  SOURCES = {
    harga_emas_org: {
      url: "https://harga-emas.org/",
      parser: :parse_harga_emas_org
    }
  }.freeze

  Result = Struct.new(:success?, :price_data, :error)

  def fetch(source: :harga_emas_org, date: Date.current)
    config = SOURCES.fetch(source)
    html = fetch_html(config[:url])

    price_data = send(config[:parser], html)

    GoldPrice.upsert_price(
      date: date,
      source: price_data.fetch(:price_source),
      price_per_gram: price_data[:price_per_gram],
      buyback_price: price_data[:buyback_price],
      metadata: {
        provider: source.to_s,
        raw_html_snippet: price_data[:raw_snippet],
        fetched_at: Time.current.iso8601
      }
    )

    Result.new(true, price_data, nil)
  rescue ParseError, KeyError => e
    Rails.logger.error("GoldPriceFetcher error: #{e.message}")
    Result.new(false, nil, e.message)
  end

  private

    def fetch_html(url_string)
      uri = URI(url_string)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Sure/#{Sure::VERSION} (+https://github.com/hendripermana/sure)"
      response = http.request(request)

      return response.body if response.is_a?(Net::HTTPSuccess)

      if response.is_a?(Net::HTTPTooManyRequests) || response.is_a?(Net::HTTPServerError)
        raise TransientError, "HTTP #{response.code} from #{uri.host}"
      end

      raise ParseError, "HTTP #{response.code} from #{uri.host}"
    end

    def parse_harga_emas_org(html)
      doc = Nokogiri::HTML(html)
      antam_table = doc.css("table").find do |table|
        table.css("th").any? { |header| header.text.squish.casecmp("Antam").zero? }
      end
      raise ParseError, "Antam price table was not found" unless antam_table

      one_gram_row = antam_table.css("tbody tr").find do |row|
        row.css("td").first&.text&.squish == "1"
      end
      cells = one_gram_row&.css("td")
      raise ParseError, "Antam 1 gram row was not found" unless cells&.length.to_i >= 2

      price_per_gram = extract_idr_amount(cells[1].text)
      buyback_match = doc.text.match(/Harga pembelian kembali:\s*Rp\s*([\d.]+)/i)
      buyback_price = extract_idr_amount(buyback_match&.captures&.first)
      raise ParseError, "Antam 1 gram price was invalid" unless price_per_gram.positive?

      {
        price_source: "antam",
        price_per_gram: price_per_gram,
        buyback_price: buyback_price.zero? ? nil : buyback_price,
        raw_snippet: one_gram_row.text.squish
      }
    end

    def extract_idr_amount(text)
      return 0.0 if text.blank?
      # Remove everything except digits
      text.gsub(/[^\d]/, "").to_d
    end
end
