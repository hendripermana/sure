class Settings::BankSyncController < ApplicationController
  layout "settings"

  # The bank_sync settings page has been consolidated into the providers page.
  # This redirect preserves old bookmarks and any links that still point here.
  def show
    redirect_to settings_providers_path, status: :moved_permanently
  end
end
