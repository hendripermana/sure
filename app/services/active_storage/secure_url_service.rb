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

        representation.url(
          expires_in: expires_in.to_i,
          disposition: disposition,
          filename: filename
        )
      rescue ActiveStorage::FileNotFoundError, ActiveStorage::InvariableError, ActiveStorage::Error => e
        Rails.logger.warn "[ActiveStorage] Unable to generate secure URL: #{e.message}"
        nil
      rescue StandardError => e
        Rails.logger.error "[ActiveStorage] Unexpected secure URL error: #{e.message}"
        nil
      end
    end
  end
end
