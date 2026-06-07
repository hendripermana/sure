require "active_support/core_ext/integer/time"
require "uri"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files using configured storage service (see config/storage.yml for options).
  # Cloudflare R2 is the default for zero-egress, cost-effective cloud storage.
  # Options: :local, :amazon, :cloudflare, :generic_s3
  config.active_storage.service = ENV.fetch("ACTIVE_STORAGE_SERVICE", "cloudflare").to_sym

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = false  # Disabled: Caddy handles SSL termination with X-Forwarded-Proto headers

  # Trust X-Forwarded-* headers from reverse proxy (Caddy with Cloudflare IPs)
  config.ssl_options = {
    hsts: { max_age: 1.year.to_i, include_subdomains: true, preload: true },
    redirect: false  # Don't force redirects; Caddy handles this
  }

  # Action Cable configuration for production WebSockets
  app_domain = ENV["APP_DOMAIN"].to_s
  action_cable_url = ENV["ACTION_CABLE_URL"].to_s

  if action_cable_url.empty? && app_domain.present?
    begin
      app_uri = URI(app_domain)
      if app_uri.host
        scheme = app_uri.scheme == "https" ? "wss" : "ws"
        host_with_port = app_uri.host
        if app_uri.port && ![ 80, 443 ].include?(app_uri.port)
          host_with_port = "#{host_with_port}:#{app_uri.port}"
        end
        action_cable_url = "#{scheme}://#{host_with_port}/cable"
      end
    rescue URI::InvalidURIError
      Rails.logger.warn("Invalid APP_DOMAIN for Action Cable: #{app_domain.inspect}")
    end
  end

  config.action_cable.url = action_cable_url if action_cable_url.present?

  allowed_origins = ENV.fetch("ACTION_CABLE_ALLOWED_ORIGINS", "")
    .split(",")
    .map(&:strip)
    .reject(&:empty?)

  if allowed_origins.empty? && app_domain.present?
    begin
      app_uri = URI(app_domain)
      if app_uri.host
        origin = "#{app_uri.scheme}://#{app_uri.host}"
        origin += ":#{app_uri.port}" if app_uri.port && ![ 80, 443 ].include?(app_uri.port)
        allowed_origins = [ origin ]
      end
    rescue URI::InvalidURIError
      Rails.logger.warn("Invalid APP_DOMAIN for Action Cable origins: #{app_domain.inspect}")
    end
  end

  config.action_cable.allowed_request_origins = allowed_origins if allowed_origins.any?

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Redis Cache Store for production performance
  # Provides fast, distributed caching with persistence
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch("REDIS_CACHE_URL") { ENV.fetch("REDIS_URL", "redis://localhost:6379/1") },

    # Connection pool configuration (Rails 8 format)
    pool: {
      size: ENV.fetch("REDIS_POOL_SIZE", 10).to_i,
      timeout: 5
    },

    # Connection timeouts for reliability
    connect_timeout: ENV.fetch("REDIS_CONNECT_TIMEOUT", 5).to_i,
    read_timeout: ENV.fetch("REDIS_READ_TIMEOUT", 1).to_i,
    write_timeout: ENV.fetch("REDIS_WRITE_TIMEOUT", 1).to_i,

    # Reconnect attempts for resilience
    reconnect_attempts: 2,

    # Cache namespace for isolation
    namespace: ENV.fetch("CACHE_NAMESPACE", "permoney_production"),

    # Compression for large values (>1KB)
    compress: true,
    compress_threshold: ENV.fetch("CACHE_COMPRESS_THRESHOLD", 1024).to_i,

    # Error handling - report to Sentry
    error_handler: lambda { |method:, returning:, exception:|
      if defined?(Sentry)
        Sentry.capture_exception(exception,
          level: "warning",
          tags: {
            cache_method: method,
            cache_returning: returning
          }
        )
      end
      Rails.logger.warn("Cache error: #{method} - #{exception.message}")
    }
  }

  # CRITICAL: Use Sidekiq as the queue adapter for persistent, reliable job processing
  # Default :async adapter is non-persistent and jobs are lost on restart!
  config.active_job.queue_adapter = :sidekiq

  smtp_configured = ENV["SMTP_ADDRESS"].present?
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.perform_deliveries = smtp_configured
  config.action_mailer.raise_delivery_errors = smtp_configured

  # Set host to be used by links generated in mailer templates.
  app_domain = ENV.fetch("APP_DOMAIN", "https://example.com")
  app_uri = URI.parse(app_domain.match?(%r{\Ahttps?://}) ? app_domain : "https://#{app_domain}")
  mailer_url_options = {
    host: app_uri.host,
    protocol: app_uri.scheme
  }
  mailer_url_options[:port] = app_uri.port unless [ 80, 443 ].include?(app_uri.port)
  config.action_mailer.default_url_options = mailer_url_options
  if smtp_configured
    config.action_mailer.smtp_settings = {
      address: ENV.fetch("SMTP_ADDRESS"),
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      user_name: ENV["SMTP_USERNAME"],
      password: ENV["SMTP_PASSWORD"],
      authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
      enable_starttls_auto: ActiveModel::Type::Boolean.new.cast(ENV.fetch("SMTP_TLS_ENABLED", true))
    }.compact
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # ===========================================================================
  # F1-LEVEL PERFORMANCE OPTIMIZATIONS (Rails 8.1 Best Practices)
  # ===========================================================================

  # Query result caching - cache identical SQL queries
  config.active_record.query_log_tags_enabled = false # Disable in prod for speed
  config.active_record.cache_versioning = true # Enable query cache versioning

  # Async query executor for better performance
  config.active_record.async_query_executor = :global_thread_pool

  # Schema cache - load database schema once instead of querying
  config.active_record.use_schema_cache_dump = true
  config.active_record.schema_cache_ignored_tables = []

  # Action Controller optimizations
  config.action_controller.enable_fragment_cache_logging = false

  # Asset optimizations
  config.assets.compile = false # Don't compile in production
  config.assets.digest = true # Use digest for cache busting
  config.assets.compress = true # Enable compression
  config.assets.css_compressor = nil # Tailwind already optimized
  config.assets.js_compressor = :terser # Compress JS with Terser

  # Gzip compression for responses
  config.middleware.insert_before ActionDispatch::Static, Rack::Deflater

  # ETag support for conditional requests
  config.action_dispatch.default_headers.merge!({
    "X-Frame-Options" => "SAMEORIGIN",
    "X-Content-Type-Options" => "nosniff",
    "X-XSS-Protection" => "0",
    "Referrer-Policy" => "strict-origin-when-cross-origin"
  })

  # ===========================================================================
  # PRODUCTION BOOT OPTIMIZATIONS
  # ===========================================================================

  # Asset precompilation optimizations
  config.assets.prefix = "/assets"

  # Skip asset compilation if assets are precompiled
  config.assets.compile = false
  config.assets.digest = true

  # Enable Rails cache to store assets digest
  # Suppress warnings during asset precompilation
  config.log_level = :error if ENV["RAILS_LOG_LEVEL"] != "debug"

  # ===========================================================================
  # MONITORING & PERFORMANCE SETUP
  # ===========================================================================

  monitoring_logger = Rails.logger || ActiveSupport::Logger.new($stdout)

  # Only enable Skylight if API key is configured
  skylight_token = ENV["SKYLIGHT_AUTHENTICATION_TOKEN"].presence || ENV["SKYLIGHT_AUTHENTICATION"].presence

  if skylight_token
    config.skylight.environments = [ "production" ]
  else
    monitoring_logger.info "Skylight disabled: SKYLIGHT_AUTHENTICATION_TOKEN/SKYLIGHT_AUTHENTICATION not configured"
  end

  # Only enable OIDC if required environment variables are present
  if ENV["OIDC_ISSUER"].present? && ENV["OIDC_CLIENT_ID"].present? && ENV["OIDC_CLIENT_SECRET"].present?
    # OIDC is properly configured, Rails will handle it
    monitoring_logger.info "OIDC enabled with issuer: #{ENV['OIDC_ISSUER']}"
  else
    # Suppress OIDC warnings in production/Docker environment
    monitoring_logger.info "OIDC disabled: missing required environment variables"
  end

  # StackProf configuration for production profiling
  if defined?(StackProf) && config.respond_to?(:stackprof)
    # Configure StackProf for production monitoring
    # Disabled by default, can be enabled via environment variable
    config.stackprof.enabled = ENV["ENABLE_STACK_PROF"] == "true"

    if config.stackprof.enabled
      monitoring_logger.info "StackProf enabled for production profiling"
    end
  elsif ENV["ENABLE_STACK_PROF"] == "true"
    monitoring_logger.warn "StackProf requested but support module not loaded; ensure the stackprof gem is in the bundle"
  end

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
