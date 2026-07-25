class FamilyExportsController < ApplicationController
  include StreamExtensions

  before_action :require_admin
  before_action :set_export, only: [ :download, :destroy ]

  def new
    # Modal view for initiating export
  end

  def create
    @export = Current.family.family_exports.create!
    FamilyDataExportJob.perform_later(@export)

    respond_to do |format|
      format.html { redirect_to imports_path, notice: "Export started. You'll be able to download it shortly." }
      format.turbo_stream {
        stream_redirect_to imports_path, notice: "Export started. You'll be able to download it shortly."
      }
    end
  end

  def index
    @exports = Current.family.family_exports.ordered.limit(10)
    render layout: false # For turbo frame
  end

  def download
    if @export.downloadable?
      url = ActiveStorage::SecureUrlService.for_attachment(
        @export.export_file,
        expires_in: 5.minutes,
        disposition: :attachment,
        filename: @export.filename
      )

      if url.present?
        parsed_url = URI.parse(url)
        allowed_hosts = %w[cloudflare.com r2.cloudflarestorage.com s3.amazonaws.com amazonaws.com]
        allowed_hosts += %w[localhost www.example.com] if Rails.env.test? || Rails.env.development?

        if parsed_url.host.present? && parsed_url.scheme.present? && allowed_hosts.any? { |host| parsed_url.host.end_with?(host) }
          redirect_to url, allow_other_host: false
        else
          redirect_to imports_path, alert: "Export not ready for download"
        end
      else
        redirect_to imports_path, alert: "Export not ready for download"
      end
    else
      redirect_to imports_path, alert: "Export not ready for download"
    end
  end

  def destroy
    @export.destroy
    redirect_to imports_path, notice: "Export deleted successfully"
  end

  private

    def set_export
      @export = Current.family.family_exports.find(params[:id])
    end

    def require_admin
      unless Current.user.admin?
        redirect_to root_path, alert: "Access denied"
      end
    end
end
