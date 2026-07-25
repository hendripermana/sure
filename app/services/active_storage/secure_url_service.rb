# frozen_string_literal: true

module ActiveStorage
  class SecureUrlService
    class << self
      def for_attachment(attachment, variant: nil, expires_in: 5.minutes, disposition: :inline, filename: nil)
        return nil unless attachment&.attached?

        blob = attachment.blob
        return nil unless blob.present?

        representation = variant.present? ? attachment.variant(variant) : attachment
        filename ||= blob.filename

        begin
          url = representation.url(
            expires_in: expires_in.to_i,
            disposition: disposition,
            filename: filename
          )
          return url if url.present?
        rescue ActiveStorage::FileNotFoundError, ActiveStorage::InvariableError, ActiveStorage::Error => e
          Rails.logger.warn "[ActiveStorage] Unable to generate secure URL: #{e.message}"
        rescue StandardError => e
          Rails.logger.error "[ActiveStorage] Unexpected secure URL error: #{e.message}"
        end

        fallback_url_for(representation, filename: filename, disposition: disposition)
      end

      private
        def fallback_url_for(representation, filename:, disposition:)
          blob = representation.respond_to?(:blob) ? representation.blob : nil
          blob ||= representation.respond_to?(:attachment) ? representation.attachment&.blob : nil
          return nil unless blob&.signed_id.present?

          route_helpers = Rails.application.routes.url_helpers
          default_url_options = Rails.application.routes.default_url_options.dup
          host = ActiveStorage::Current.url_options&.dig(:host) || default_url_options[:host] || Rails.application.config.action_controller.default_url_options&.dig(:host) || "localhost"
          protocol = ActiveStorage::Current.url_options&.dig(:protocol) || default_url_options[:protocol] || "https"

          return nil if host.blank?

          if representation.is_a?(ActiveStorage::VariantWithRecord)
            route_helpers.rails_blob_representation_url(
              blob.signed_id,
              representation.variation.key,
              filename: filename,
              disposition: disposition,
              host: host,
              protocol: protocol
            )
          else
            route_helpers.rails_blob_url(
              blob.signed_id,
              filename: filename,
              disposition: disposition,
              host: host,
              protocol: protocol
            )
          end
        rescue StandardError => e
          Rails.logger.error "[ActiveStorage] Fallback secure URL generation failed: #{e.message}"
          nil
      end
    end
  end
end
