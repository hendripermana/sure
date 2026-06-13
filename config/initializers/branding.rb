# Branding configuration initializer
# This provides a centralized way to access branding settings throughout the application

module Branding
  class << self
    # Helper method to safely access Setting model (handles database not available)
    def safe_setting_access(setting_method)
      # During asset precompilation (RAILS_ENV=production but no DB), skip database access
      return nil if ENV["RAILS_ENV"] == "production" && !database_available?

      return nil unless defined?(Setting)
      return nil unless Setting.table_exists?

      Setting.respond_to?(setting_method) ? Setting.public_send(setting_method) : nil
    rescue StandardError
      # Fallback to environment variables if any error occurs
      nil
    end

    # Check if database is available (used during asset precompilation)
    def database_available?
      return false unless defined?(ActiveRecord::Base)
      return false unless ActiveRecord::Base.connected?

      # Simple ping to check database connectivity
      ActiveRecord::Base.connection.execute("SELECT 1")
      true
    rescue StandardError
      false
    end

    # Get app name from settings or environment
    def app_name
      @app_name ||= safe_setting_access(:app_name) || ENV.fetch("APP_NAME", "Sure")
    end

    # Get app short name from settings or environment
    def app_short_name
      @app_short_name ||= safe_setting_access(:app_short_name) || ENV.fetch("APP_SHORT_NAME", "Sure")
    end

    # Get app description from settings or environment
    def app_description
      @app_description ||= safe_setting_access(:app_description) || ENV.fetch("APP_DESCRIPTION", "The personal finance app for everyone")
    end

    # Get GitHub repository owner from settings or environment
    def github_repo_owner
      @github_repo_owner ||= safe_setting_access(:github_repo_owner) || ENV.fetch("GITHUB_REPO_OWNER", "hendripermana")
    end

    # Get GitHub repository name from settings or environment
    def github_repo_name
      @github_repo_name ||= safe_setting_access(:github_repo_name) || ENV.fetch("GITHUB_REPO_NAME", "sure")
    end

    # Get GitHub repository branch from settings or environment
    def github_repo_branch
      @github_repo_branch ||= safe_setting_access(:github_repo_branch) || ENV.fetch("GITHUB_REPO_BRANCH", "main")
    end

    # Get full GitHub repository URL
    def github_repo_url
      "https://github.com/#{github_repo_owner}/#{github_repo_name}"
    end

    # Get OAuth default scopes from settings or environment
    def oauth_default_scopes
      @oauth_default_scopes ||= safe_setting_access(:oauth_default_scopes) || ENV.fetch("OAUTH_DEFAULT_SCOPES", "read_accounts read_transactions read_balances")
    end

    # Clear cached values (useful for testing or when settings change)
    def clear_cache!
      instance_variables.each { |var| remove_instance_variable(var) }
    end
  end
end

# Make branding configuration available globally
Rails.application.config.branding = Branding
