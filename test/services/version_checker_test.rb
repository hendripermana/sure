# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class VersionCheckerTest < ActiveSupport::TestCase
  include WebMock::API
  setup do
    # Clear cache before each test
    Rails.cache.delete(VersionChecker::CACHE_KEY)
  end

  test "should return nil when GitHub API is unreachable" do
    stub_request(:get, VersionChecker::GITHUB_API_URL)
      .to_raise(StandardError)

    release = VersionChecker.latest_release
    assert_nil release
  end

  test "should cache release information" do
    mock_release = {
      "tag_name" => "v1.0.0",
      "html_url" => "https://github.com/hendripermana/sure/releases/tag/v1.0.0",
      "body" => "New features and improvements",
      "published_at" => "2025-01-01T00:00:00Z",
      "prerelease" => false,
      "draft" => false
    }

    stub_request(:get, VersionChecker::GITHUB_API_URL)
      .to_return(status: 200, body: mock_release.to_json)

    # First call should hit the API
    first_call = VersionChecker.latest_release
    assert_equal "1.0.0", first_call[:version]

    # Second call should return cached value without hitting API
    second_call = VersionChecker.latest_release
    assert_equal first_call, second_call
  end

  test "should correctly detect when update is available" do
    mock_release = {
      "tag_name" => "v1.0.0",
      "html_url" => "https://github.com/hendripermana/sure/releases/tag/v1.0.0",
      "body" => "New features",
      "published_at" => "2025-01-01T00:00:00Z",
      "prerelease" => false,
      "draft" => false
    }

    stub_request(:get, VersionChecker::GITHUB_API_URL)
      .to_return(status: 200, body: mock_release.to_json)

    Sure.stubs(:version).returns(Semver.new("0.96"))

    # Current version is 0.96, available is 1.0.0
    assert VersionChecker.update_available?
  end

  test "should correctly detect when update is not available" do
    mock_release = {
      "tag_name" => "v0.96",
      "html_url" => "https://github.com/hendripermana/sure/releases/tag/v0.96",
      "body" => "Current version",
      "published_at" => "2025-01-01T00:00:00Z",
      "prerelease" => false,
      "draft" => false
    }

    stub_request(:get, VersionChecker::GITHUB_API_URL)
      .to_return(status: 200, body: mock_release.to_json)

    Sure.stubs(:version).returns(Semver.new("0.96"))

    # Current version is 0.96, available is 0.96
    refute VersionChecker.update_available?
  end

  test "should return latest version number" do
    mock_release = {
      "tag_name" => "v1.0.0",
      "html_url" => "https://github.com/hendripermana/sure/releases/tag/v1.0.0",
      "body" => "Release",
      "published_at" => "2025-01-01T00:00:00Z",
      "prerelease" => false,
      "draft" => false
    }

    stub_request(:get, VersionChecker::GITHUB_API_URL)
      .to_return(status: 200, body: mock_release.to_json)

    assert_equal "1.0.0", VersionChecker.latest_version
  end

  test "should return release URL" do
    mock_release = {
      "tag_name" => "v1.0.0",
      "html_url" => "https://github.com/hendripermana/sure/releases/tag/v1.0.0",
      "body" => "Release",
      "published_at" => "2025-01-01T00:00:00Z",
      "prerelease" => false,
      "draft" => false
    }

    stub_request(:get, VersionChecker::GITHUB_API_URL)
      .to_return(status: 200, body: mock_release.to_json)

    assert_equal "https://github.com/hendripermana/sure/releases/tag/v1.0.0", VersionChecker.release_url
  end

  test "should handle rate limiting gracefully" do
    stub_request(:get, VersionChecker::GITHUB_API_URL)
      .to_return(status: 429) # Too Many Requests

    release = VersionChecker.latest_release
    assert_nil release
  end

  test "should handle 304 Not Modified gracefully" do
    stub_request(:get, VersionChecker::GITHUB_API_URL)
      .to_return(status: 304) # Not Modified

    release = VersionChecker.latest_release
    assert_nil release
  end
end
