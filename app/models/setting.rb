# Dynamic settings the user can change within the app (helpful for self-hosting)
class Setting < RailsSettings::Base
  class ValidationError < StandardError; end

  cache_prefix { "v1" }

  # Third-party API keys (upstream: better comment)
  field :twelve_data_api_key, type: :string, default: ENV["TWELVE_DATA_API_KEY"]
  field :openai_access_token, type: :string, default: ENV["OPENAI_ACCESS_TOKEN"]
  field :openai_uri_base, type: :string, default: ENV["OPENAI_URI_BASE"]
  field :openai_model, type: :string, default: ENV["OPENAI_MODEL"]
  field :openai_json_mode, type: :string, default: ENV["LLM_JSON_MODE"]
  field :brand_fetch_client_id, type: :string, default: ENV["BRAND_FETCH_CLIENT_ID"]

  # Pending transaction sync behavior (SimpleFIN + Plaid)
  pending_env = ENV["SIMPLEFIN_INCLUDE_PENDING"].to_s.strip.downcase
  field :syncs_include_pending, type: :boolean, default: pending_env.blank? ? true : !%w[0 false no off].include?(pending_env)

  # Sync provider global enable/disable toggles
  field :plaid_enabled, type: :boolean, default: ENV["DISABLE_PLAID"] != "true"
  field :simplefin_enabled, type: :boolean, default: ENV["DISABLE_SIMPLEFIN"] != "true"
  field :lunchflow_enabled, type: :boolean, default: ENV["DISABLE_LUNCHFLOW"] != "true"

  # Upstream: Single hash field for all dynamic provider credentials and other dynamic settings
  # This allows unlimited dynamic fields without declaring them upfront
  field :dynamic_fields, type: :hash, default: {}

  # Upstream: Onboarding and app settings
  ONBOARDING_STATES = %w[open closed invite_only].freeze
  DEFAULT_ONBOARDING_STATE = begin
    env_value = ENV["ONBOARDING_STATE"].to_s.presence || "open"
    ONBOARDING_STATES.include?(env_value) ? env_value : "open"
  end

  field :onboarding_state, type: :string, default: DEFAULT_ONBOARDING_STATE

  # User Management
  field :require_invite_for_signup, type: :boolean, default: false
  field :require_email_confirmation, type: :boolean, default: ENV.fetch("REQUIRE_EMAIL_CONFIRMATION", "true") == "true"

  # Sure: Branding Configuration
  field :app_name, type: :string, default: ENV.fetch("APP_NAME", "Sure")
  field :app_short_name, type: :string, default: ENV.fetch("APP_SHORT_NAME", "Sure")
  field :app_description, type: :string, default: ENV.fetch("APP_DESCRIPTION", "The personal finance app for everyone")
  field :github_repo_owner, type: :string, default: ENV.fetch("GITHUB_REPO_OWNER", "hendripermana")
  field :github_repo_name, type: :string, default: ENV.fetch("GITHUB_REPO_NAME", "sure")
  field :github_repo_branch, type: :string, default: ENV.fetch("GITHUB_REPO_BRANCH", "main")

  # Sure: OAuth Configuration
  field :oauth_default_scopes, type: :string, default: ENV.fetch("OAUTH_DEFAULT_SCOPES", "read_accounts read_transactions read_balances")

  # Sure: Deployment Configuration
  field :docker_image_name, type: :string, default: ENV.fetch("DOCKER_IMAGE_NAME", "ghcr.io/hendripermana/sure")
  field :docker_image_tag, type: :string, default: ENV.fetch("DOCKER_IMAGE_TAG", "latest")
  field :deployment_path, type: :string, default: ENV.fetch("DEPLOYMENT_PATH", "/home/ubuntu/sure")

  # Upstream: Validation and dynamic field access methods
  def self.validate_onboarding_state!(state)
    return if ONBOARDING_STATES.include?(state)

    raise ValidationError, I18n.t("settings.hostings.update.invalid_onboarding_state")
  end

  class << self
    alias_method :raw_onboarding_state, :onboarding_state
    alias_method :raw_onboarding_state=, :onboarding_state=
    alias_method :raw_openai_uri_base, :openai_uri_base
    alias_method :raw_openai_uri_base=, :openai_uri_base=

    def onboarding_state
      value = raw_onboarding_state
      return "invite_only" if value.blank? && require_invite_for_signup

      value.presence || DEFAULT_ONBOARDING_STATE
    end

    def onboarding_state=(state)
      validate_onboarding_state!(state)
      self.require_invite_for_signup = state == "invite_only"
      self.raw_onboarding_state = state
    end

    def openai_uri_base
      raw_openai_uri_base.presence
    end

    def openai_uri_base=(value)
      self.raw_openai_uri_base = value.presence
    end

    # Upstream: Support dynamic field access via bracket notation
    # First checks if it's a declared field, then falls back to dynamic_fields hash
    def [](key)
      key_str = key.to_s

      # Check if it's a declared field first
      if respond_to?(key_str)
        public_send(key_str)
      else
        # Fall back to dynamic_fields hash
        dynamic_fields[key_str]
      end
    end

    def []=(key, value)
      key_str = key.to_s

      # If it's a declared field, use the setter
      if respond_to?("#{key_str}=")
        public_send("#{key_str}=", value)
      else
        # Otherwise, manage in dynamic_fields hash
        current_dynamic = dynamic_fields.dup
        if value.nil?
          current_dynamic.delete(key_str)          # treat nil as delete
        else
          current_dynamic[key_str] = value
        end
        self.dynamic_fields = current_dynamic      # persists & busts cache
      end
    end

    # Check if a dynamic field exists (useful to distinguish nil value vs missing key)
    def key?(key)
      key_str = key.to_s
      respond_to?(key_str) || dynamic_fields.key?(key_str)
    end

    # Delete a dynamic field
    def delete(key)
      key_str = key.to_s
      return nil if respond_to?(key_str) # Can't delete declared fields

      current_dynamic = dynamic_fields.dup
      value = current_dynamic.delete(key_str)
      self.dynamic_fields = current_dynamic
      value
    end

    # List all dynamic field keys (excludes declared fields)
    def dynamic_keys
      dynamic_fields.keys
    end
  end

  # Upstream: Validates OpenAI configuration requires model when custom URI base is set
  def self.validate_openai_config!(uri_base: nil, model: nil)
    # Use provided values or current settings
    uri_base_value = uri_base.nil? ? openai_uri_base : uri_base
    model_value = model.nil? ? openai_model : model

    # If custom URI base is set, model must also be set
    if uri_base_value.present? && model_value.blank?
      raise ValidationError, "OpenAI model is required when custom URI base is configured"
    end
  end
end
