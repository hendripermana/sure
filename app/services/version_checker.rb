# frozen_string_literal: true

# Service untuk check latest version dari GitHub releases
# Implements proper caching dan rate limiting
class VersionChecker
  GITHUB_REPO = "hendripermana/sure"
  CACHE_KEY = "sure:latest_release"
  CACHE_DURATION = 24.hours
  GITHUB_API_URL = "https://api.github.com/repos/#{GITHUB_REPO}/releases/latest"

  class << self
    def latest_release
      fetch_and_cache_release
    end

    def update_available?
      latest = latest_release
      return false unless latest

      Semver.new(latest[:version]) > Semver.new(Sure.version.to_s)
    end

    def latest_version
      latest = latest_release
      latest&.dig(:version)
    end

    def release_url
      latest = latest_release
      latest&.dig(:html_url)
    end

    def release_body
      latest = latest_release
      latest&.dig(:body)
    end

    private

      def fetch_and_cache_release
        # Try to get from cache first
        cached = Rails.cache.read(CACHE_KEY)
        return cached if cached.present?

        # Fetch from GitHub API
        release = fetch_from_github
        return nil unless release

        # Cache the result
        Rails.cache.write(CACHE_KEY, release, expires_in: CACHE_DURATION)
        release
      end

      def fetch_from_github
        require "net/http"
        require "json"

        uri = URI(GITHUB_API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 5
        http.open_timeout = 5

        request = Net::HTTP::Get.new(uri)
        request["Accept"] = "application/vnd.github.v3+json"
        request["User-Agent"] = "Sure/#{Sure.version}"

        response = http.request(request)

        case response.code.to_i
        when 200
          parse_release(JSON.parse(response.body))
        when 304, 403, 429
          # Cached, Forbidden, or Rate Limited - silently fail
          Rails.logger.warn("GitHub API rate limit or access issue: #{response.code}")
          nil
        else
          Rails.logger.error("Failed to fetch GitHub release: #{response.code}")
          nil
        end
      rescue StandardError => e
        Rails.logger.error("Error fetching GitHub release: #{e.message}")
        nil
      end

      def parse_release(data)
        {
          version: data["tag_name"]&.sub(/^v/, ""),
          html_url: data["html_url"],
          body: data["body"],
          published_at: data["published_at"],
          prerelease: data["prerelease"],
          draft: data["draft"]
        }
      end
  end
end
