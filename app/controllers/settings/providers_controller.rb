class Settings::ProvidersController < ApplicationController
  layout "settings"

  before_action :ensure_admin, only: [ :show, :update, :test_connection ]

  def show
    @breadcrumbs = [
      { text: "Home", href: root_path, icon: "home" },
      { text: "Bank Sync Providers", icon: "plug" }
    ]

    prepare_show_context
  end

  def update
    # Build index of valid configurable fields with their metadata
    Provider::Factory.ensure_adapters_loaded
    valid_fields = {}
    Provider::ConfigurationRegistry.all.each do |config|
      config.fields.each do |field|
        valid_fields[field.setting_key.to_s] = field
      end
    end

    updated_fields = []

    # This hash will store only the updates for dynamic (non-declared) fields
    dynamic_updates = {}

    # Perform all updates within a transaction for consistency
    Setting.transaction do
      # Handle global toggles first
      %w[plaid_enabled simplefin_enabled lunchflow_enabled].each do |toggle|
        next unless provider_params.key?(toggle)
        value = provider_params[toggle] == "1"
        Setting.public_send("#{toggle}=", value)
        updated_fields << toggle
      end

      provider_params.each do |param_key, param_value|
        # Skip toggle params as we handled them above
        next if %w[plaid_enabled simplefin_enabled lunchflow_enabled].include?(param_key.to_s)
        # Only process keys that exist in the configuration registry
        field = valid_fields[param_key.to_s]
        next unless field

        # Clean the value and convert blank/empty strings to nil
        value = param_value.to_s.strip
        value = nil if value.empty?

        # For secret fields only, skip placeholder values to prevent accidental overwrite
        if field.secret && value == "********"
          next
        end

        key_str = field.setting_key.to_s

        # Check if the setting is a declared field in setting.rb
        # Use method_defined? to check if the setter actually exists on the singleton class,
        # not just respond_to? which returns true for dynamic fields due to respond_to_missing?
        if Setting.singleton_class.method_defined?("#{key_str}=")
          # If it's a declared field (e.g., openai_model), set it directly.
          # This is safe and uses the proper setter.
          Setting.public_send("#{key_str}=", value)
        else
          # If it's a dynamic field, add it to our batch hash
          # to avoid the Read-Modify-Write conflict.
          dynamic_updates[key_str] = value
        end

        updated_fields << param_key
      end

      # Now, if we have any dynamic updates, apply them all at once
      if dynamic_updates.any?
        # 1. READ the current hash once
        current_dynamic = Setting.dynamic_fields.dup

        # 2. MODIFY by merging changes
        # Treat nil values as deletions to keep the hash clean
        dynamic_updates.each do |key, value|
          if value.nil?
            current_dynamic.delete(key)
          else
            current_dynamic[key] = value
          end
        end

        # 3. WRITE the complete, merged hash back once
        Setting.dynamic_fields = current_dynamic
      end
    end

    if updated_fields.any?
      # Reload provider configurations if needed
      reload_provider_configs(updated_fields)

      redirect_to settings_providers_path, notice: "Provider settings updated successfully"
    else
      redirect_to settings_providers_path, notice: "No changes were made"
    end
  rescue => error
    Rails.logger.error("Failed to update provider settings: #{error.message}")
    flash.now[:alert] = "Failed to update provider settings: #{error.message}"
    prepare_show_context
    render :show, status: :unprocessable_entity
  end

  def test_connection
    provider_key = params[:provider_key].to_s.downcase

    success = false
    message = ""

    case provider_key
    when "plaid"
      client_id = Setting["plaid_client_id"].presence || ENV["PLAID_CLIENT_ID"]
      secret = Setting["plaid_secret"].presence || ENV["PLAID_SECRET"]
      env = Setting["plaid_environment"].presence || ENV["PLAID_ENV"] || "sandbox"

      if client_id.blank? || secret.blank?
        message = "Client ID and Secret Key are not configured."
      else
        begin
          config = Plaid::Configuration.new
          config.server_index = Plaid::Configuration::Environment[env]
          config.api_key["PLAID-CLIENT-ID"] = client_id
          config.api_key["PLAID-SECRET"] = secret

          client = Plaid::PlaidApi.new(Plaid::ApiClient.new(config))
          client.categories_get({})
          success = true
          message = "Connection successful! Plaid US API credentials are valid."
        rescue Plaid::ApiError => e
          body = JSON.parse(e.response_body || "{}")
          error_message = body["error_message"] || body["error_code"] || e.message
          message = "Plaid API error: #{error_message}"
        rescue => e
          message = "Connection failed: #{e.message}"
        end
      end

    when "plaid_eu"
      client_id = Setting["plaid_eu_client_id"].presence || ENV["PLAID_EU_CLIENT_ID"]
      secret = Setting["plaid_eu_secret"].presence || ENV["PLAID_EU_SECRET"]
      env = Setting["plaid_eu_environment"].presence || ENV["PLAID_EU_ENV"] || "sandbox"

      if client_id.blank? || secret.blank?
        message = "Client ID and Secret Key are not configured."
      else
        begin
          config = Plaid::Configuration.new
          config.server_index = Plaid::Configuration::Environment[env]
          config.api_key["PLAID-CLIENT-ID"] = client_id
          config.api_key["PLAID-SECRET"] = secret

          client = Plaid::PlaidApi.new(Plaid::ApiClient.new(config))
          client.categories_get({})
          success = true
          message = "Connection successful! Plaid EU API credentials are valid."
        rescue Plaid::ApiError => e
          body = JSON.parse(e.response_body || "{}")
          error_message = body["error_message"] || body["error_code"] || e.message
          message = "Plaid API error: #{error_message}"
        rescue => e
          message = "Connection failed: #{e.message}"
        end
      end

    when "lunchflow"
      api_key = Setting["lunchflow_api_key"].presence || ENV["LUNCHFLOW_API_KEY"]
      base_url = Setting["lunchflow_base_url"].presence || ENV["LUNCHFLOW_BASE_URL"] || "https://lunchflow.app/api/v1"

      if api_key.blank?
        message = "API Key is not configured."
      else
        begin
          provider = Provider::Lunchflow.new(api_key, base_url: base_url)
          provider.get_accounts
          success = true
          message = "Connection successful! Lunch Flow API key is valid."
        rescue Provider::Lunchflow::LunchflowError => e
          message = "Lunch Flow error: #{e.message}"
        rescue => e
          message = "Connection failed: #{e.message}"
        end
      end

    when "simplefin"
      items = Current.family.simplefin_items.active
      if items.empty?
        message = "No active SimpleFIN connections found to test. Please add a connection first."
      else
        success_count = 0
        failed_messages = []

        items.each do |item|
          begin
            next if item.access_url.blank?
            uri = URI.parse(item.access_url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = (uri.scheme == "https")
            http.open_timeout = 10
            http.read_timeout = 10

            request = Net::HTTP::Get.new(uri.request_uri)
            if uri.user.present? && uri.password.present?
              request.basic_auth(uri.user, uri.password)
            end

            response = http.request(request)
            if response.code.to_i == 200
              success_count += 1
            else
              failed_messages << "#{item.name}: HTTP #{response.code}"
            end
          rescue => e
            failed_messages << "#{item.name}: #{e.message}"
          end
        end

        if success_count == items.count
          success = true
          message = "Connection successful! All #{success_count} SimpleFIN connections are active."
        else
          message = "Connection partially failed: #{success_count} succeeded, #{items.count - success_count} failed. Errors: #{failed_messages.join(', ')}"
        end
      end

    else
      message = "Unknown provider: #{provider_key}"
    end

    render json: { success: success, message: message }
  end

  private
    def provider_params
      # Dynamically permit all provider configuration fields
      Provider::Factory.ensure_adapters_loaded
      permitted_fields = [ :plaid_enabled, :simplefin_enabled, :lunchflow_enabled ]

      Provider::ConfigurationRegistry.all.each do |config|
        config.fields.each do |field|
          permitted_fields << field.setting_key
        end
      end

      params.require(:setting).permit(*permitted_fields)
    end

    def ensure_admin
      redirect_to settings_providers_path, alert: "Not authorized" unless Current.user.admin?
    end

    # Reload provider configurations after settings update
    def reload_provider_configs(updated_fields)
      # Build a set of provider keys that had fields updated
      updated_provider_keys = Set.new

      # Look up the provider key directly from the configuration registry
      updated_fields.each do |field_key|
        Provider::ConfigurationRegistry.all.each do |config|
          field = config.fields.find { |f| f.setting_key.to_s == field_key.to_s }
          if field
            updated_provider_keys.add(field.provider_key)
            break
          end
        end
      end

      # Reload configuration for each updated provider
      updated_provider_keys.each do |provider_key|
        adapter_class = Provider::ConfigurationRegistry.get_adapter_class(provider_key)
        adapter_class&.reload_configuration
      end
    end

    def prepare_show_context
      Provider::Factory.ensure_adapters_loaded
      @plaid_config = Provider::ConfigurationRegistry.get("plaid")
      @plaid_eu_config = Provider::ConfigurationRegistry.get("plaid_eu")
      @lunchflow_config = Provider::ConfigurationRegistry.get("lunchflow")

      @plaid_items = Current.family.plaid_items.active.ordered
      @simplefin_items = Current.family.simplefin_items.active.ordered
      @lunchflow_items = Current.family.lunchflow_items.active.ordered
    end
end
