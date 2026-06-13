# Force managed mode for tests (self-hosted guards disable subscriptions/invitations)
ENV["SELF_HOSTED"] = "false"
ENV["SELF_HOSTING_ENABLED"] = "false"

if ENV["COVERAGE"] == "true"
  require "simplecov"
  SimpleCov.start "rails" do
    enable_coverage :branch
  end
end

require_relative "../config/environment"
# Force managed mode in tests regardless of .env
Rails.configuration.app_mode = "managed".inquiry

ENV["RAILS_ENV"] ||= "test"

# Mock Redis for self-hosting Redis configuration check
# In test environment, we don't need actual Redis connection
Redis.singleton_class.prepend(Module.new do
  def new(*args, **kwargs)
    @__redis_mock ||= Class.new do
      def initialize
        @store = Hash.new { |h, k| h[k] = {} }
      end

      def ping
        "PONG"
      end

      def hincrby(key, field, increment)
        @store[key][field] = (@store[key][field] || 0) + increment.to_i
      end

      def expire(_key, _ttl)
        true
      end

      def hget(key, field)
        @store[key][field]
      end

      def del(key)
        @store.delete(key)
        true
      end

      def multi
        yield self
      end
    end.new
  end
end)

# Set Plaid to sandbox mode for tests
ENV["PLAID_ENV"] = "sandbox"
ENV["PLAID_CLIENT_ID"] ||= "test_client_id"
ENV["PLAID_SECRET"] ||= "test_secret"
ENV["API_RATE_LIMITING_ENABLED"] ||= "true"

# Fixes Segfaults on M1 Macs when running tests in parallel (temporary workaround)
ENV["PGGSSENCMODE"] = "disable"

require "rails/test_help"
require "minitest/autorun"
require "mocha/minitest"
require "aasm/minitest"

VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.ignore_localhost = true
  config.default_cassette_options = { erb: true }
  config.filter_sensitive_data("<OPENAI_ACCESS_TOKEN>") { ENV["OPENAI_ACCESS_TOKEN"] }
  config.filter_sensitive_data("<OPENAI_ORGANIZATION_ID>") { ENV["OPENAI_ORGANIZATION_ID"] }
  config.filter_sensitive_data("<STRIPE_SECRET_KEY>") { ENV["STRIPE_SECRET_KEY"] }
  config.filter_sensitive_data("<STRIPE_WEBHOOK_SECRET>") { ENV["STRIPE_WEBHOOK_SECRET"] }
  config.filter_sensitive_data("<PLAID_CLIENT_ID>") { ENV["PLAID_CLIENT_ID"] }
  config.filter_sensitive_data("<PLAID_SECRET>") { ENV["PLAID_SECRET"] }
end

# Configure OmniAuth for testing
OmniAuth.config.test_mode = true
# Allow both GET and POST for OIDC callbacks in tests
OmniAuth.config.allowed_request_methods = [ :get, :post ]

# OpenAI: mock responses in test to avoid external calls and flaky VCR reliance
if Rails.env.test?
  module Provider::OpenaiTestMock
    def auto_categorize(transactions:, **)
      mapped = transactions.map do |txn|
        name = txn[:name].downcase
        category =
          case name
          when /mcdonalds/ then "Fast Food"
          when /amazon/ then "Shopping"
          when /netflix/ then "Subscriptions"
          when /paycheck/ then "Income"
          when /dinner/ then "Restaurants"
          else nil
          end
        Provider::LlmConcept::AutoCategorization.new(txn[:id], category)
      end

      Provider::Response.new(success?: true, data: mapped, error: nil)
    end

    def auto_detect_merchants(transactions:, **)
      mapped = transactions.map do |txn|
        name = txn[:name].downcase
        case name
        when /mcdonalds/ then Provider::LlmConcept::AutoDetectedMerchant.new(txn[:id], "McDonald's", "mcdonalds.com")
        when /local pub/ then Provider::LlmConcept::AutoDetectedMerchant.new(txn[:id], nil, nil)
        when /wmt/ then Provider::LlmConcept::AutoDetectedMerchant.new(txn[:id], "Walmart", "walmart.com")
        when /amzn/ then Provider::LlmConcept::AutoDetectedMerchant.new(txn[:id], "Amazon", "amazon.com")
        when /chase/ then Provider::LlmConcept::AutoDetectedMerchant.new(txn[:id], nil, nil)
        when /deposit/ then Provider::LlmConcept::AutoDetectedMerchant.new(txn[:id], nil, nil)
        when /shooters/ then Provider::LlmConcept::AutoDetectedMerchant.new(txn[:id], "Shooters", nil)
        when /microsoft/ then Provider::LlmConcept::AutoDetectedMerchant.new(txn[:id], "Microsoft", "microsoft.com")
        else Provider::LlmConcept::AutoDetectedMerchant.new(txn[:id], nil, nil)
        end
      end

      Provider::Response.new(success?: true, data: mapped, error: nil)
    end

    def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil, **)
      if model.to_s.include?("invalid")
        return Provider::Response.new(success?: false, data: nil, error: Provider::Openai::Error.new("invalid model"))
      end

      if functions.present? || function_results.present? || previous_response_id.present?
        if function_results.present? || previous_response_id.present?
          msg = Provider::LlmConcept::ChatMessage.new("m2", "$10,000 net worth")
          resp = Provider::LlmConcept::ChatResponse.new("resp-2", model, [ msg ], [])
          if streamer
            streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: "$10,000", usage: nil))
            streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: resp, usage: nil))
          end
          Provider::Response.new(success?: true, data: resp, error: nil)
        else
          fr = Provider::LlmConcept::ChatFunctionRequest.new("fr1", "call_1", "get_net_worth", "{}")
          resp = Provider::LlmConcept::ChatResponse.new("resp-1", model, [], [ fr ])
          streamer&.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: resp, usage: nil))
          Provider::Response.new(success?: true, data: resp, error: nil)
        end
      else
        msg = Provider::LlmConcept::ChatMessage.new("m1", "Yes")
        resp = Provider::LlmConcept::ChatResponse.new("resp-basic", model, [ msg ], [])
        if streamer
          streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: "Yes", usage: nil))
          streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: resp, usage: nil))
        end
        Provider::Response.new(success?: true, data: resp, error: nil)
      end
    end
  end

  Provider::Openai.prepend(Provider::OpenaiTestMock)
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors) unless ENV["DISABLE_PARALLELIZATION"] == "true"

    # https://github.com/simplecov-ruby/simplecov/issues/718#issuecomment-538201587
    if ENV["COVERAGE"] == "true"
      parallelize_setup do |worker|
        SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}"
      end

      parallelize_teardown do |worker|
        SimpleCov.result
      end
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def sign_in(user)
      post sessions_path, params: { email: user.email, password: user_password_test }
    end

    def sign_out(user = nil)
      session_record = if user.present?
        user.sessions.order(created_at: :desc).first
      else
        Session.order(created_at: :desc).first
      end

      delete session_path(session_record) if session_record.present?
    end

    def with_env_overrides(overrides = {}, &block)
      ClimateControl.modify(**overrides, &block)
    end

    def with_app_mode(mode)
      original_mode = Rails.configuration.app_mode
      Rails.configuration.app_mode = mode.inquiry
      yield
    ensure
      Rails.configuration.app_mode = original_mode
    end

    def with_self_hosting(&block)
      with_app_mode("self_hosted", &block)
    end

    def without_self_hosting(&block)
      with_app_mode("managed", &block)
    end

    def user_password_test
      "maybetestpassword817983172"
    end
  end
end

Dir[Rails.root.join("test", "support", "**", "*.rb")].each { |f| require f }
Dir[Rails.root.join("test", "interfaces", "**", "*.rb")].each { |f| require f }
