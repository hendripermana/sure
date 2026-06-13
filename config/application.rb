require_relative "boot"

require "rails/all"

# Load our ActiveSupport::Configurable shim before any gems need it
# This prevents the deprecated constant warning in Rails 8.1
require_relative "../lib/active_support/configurable"

# Load middleware for Prometheus APM (Phase 2 optimization)
require_relative "../app/middleware/rails_metrics_middleware"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Load Pagy early for controller integration in Rails 8.1
# This ensures Pagy::Method is available before controllers are loaded
begin
  require "pagy"
rescue LoadError
  # Pagy not available in this environment
end

module Sure
  class Application < Rails::Application
    # Initialize configuration defaults for Rails 8.1
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # Also ignore active_support since it's a shim loaded before Rails
    # Money is loaded as a subdirectory with its own structure
    config.autoload_lib(ignore: %w[assets tasks active_support])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # TODO: This is here for incremental adoption of localization.  This can be removed when all translations are implemented.
    config.i18n.fallbacks = true

    config.app_mode = (ENV["SELF_HOSTED"] == "true" || ENV["SELF_HOSTING_ENABLED"] == "true" ? "self_hosted" : "managed").inquiry

    # Self hosters can optionally set their own encryption keys if they want to use ActiveRecord encryption.
    if Rails.application.credentials.active_record_encryption.present?
      config.active_record.encryption = Rails.application.credentials.active_record_encryption
    end

    config.view_component.preview_controller = "LookbooksController"
    config.lookbook.preview_display_options = {
      theme: [ "light", "dark" ] # available in view as params[:theme]
    }

    # Enable Rack::Attack middleware for API rate limiting
    config.middleware.use Rack::Attack

    # Enable HTTP compression for faster asset delivery
    # Compresses responses with Gzip/Brotli for supported clients
    # Improves loading time by 60-80% for text-based assets
    config.middleware.use Rack::Deflater

    # Rails metrics middleware for Prometheus (Phase 2 APM optimization)
    config.middleware.insert_after Rack::Deflater, RailsMetricsMiddleware

    # Sure: Dynamic branding configuration (used by helpers and mailers)
    config.x.brand_name = ENV.fetch("BRAND_NAME", "Sure")
    config.x.product_name = ENV.fetch("PRODUCT_NAME", "Finance")
  end
end
