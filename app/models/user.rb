class User < ApplicationRecord
  has_secure_password

  belongs_to :family, optional: true
  belongs_to :last_viewed_chat, class_name: "Chat", optional: true
  has_many :sessions, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many :api_keys, dependent: :destroy
  has_many :mobile_devices, dependent: :destroy
  has_many :invitations, foreign_key: :inviter_id, dependent: :destroy
  has_many :impersonator_support_sessions, class_name: "ImpersonationSession", foreign_key: :impersonator_id, dependent: :destroy
  has_many :impersonated_support_sessions, class_name: "ImpersonationSession", foreign_key: :impersonated_id, dependent: :destroy
  has_many :provider_directories, dependent: :destroy
  # Upstream: OpenID Connect support
  has_many :oidc_identities, dependent: :destroy
  accepts_nested_attributes_for :family, update_only: true

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :ensure_valid_profile_image
  validates :default_period, inclusion: { in: Period::PERIODS.keys }
  validates :default_account_order, inclusion: { in: AccountOrder::ORDERS.keys }
  validates :password, length: { minimum: 8 }, allow_nil: true
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :unconfirmed_email, with: ->(email) { email&.strip&.downcase }

  normalizes :first_name, :last_name, with: ->(value) { value.strip.presence }

  enum :role, { member: "member", admin: "admin", super_admin: "super_admin" }, validate: true

  # Rails 8.1: Optimized ActiveStorage with preprocessed variants for blazing fast performance
  # Reference: https://guides.rubyonrails.org/active_storage_overview.html#transforming-images
  has_one_attached :profile_image do |attachable|
    # Preprocessed variants are generated immediately after upload for instant display
    # This follows F1 performance optimization - always ready to serve
    attachable.variant :small, resize_to_fill: [ 72, 72 ], convert: :webp, saver: { quality: 85, strip: true }, preprocessed: true
    attachable.variant :medium, resize_to_fill: [ 200, 200 ], convert: :webp, saver: { quality: 85, strip: true }, preprocessed: true

    # Lazy-loaded variant for larger displays (on-demand processing)
    attachable.variant :thumbnail, resize_to_fill: [ 300, 300 ], convert: :webp, saver: { quality: 80, strip: true }
  end

  validate :profile_image_size

  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  generates_token_for :email_confirmation, expires_in: 1.day do
    unconfirmed_email
  end

  def pending_email_change?
    unconfirmed_email.present?
  end

  def initiate_email_change(new_email)
    return false if new_email == email

    if Rails.application.config.app_mode.self_hosted? && !Setting.require_email_confirmation
      update(email: new_email)
    else
      if update(unconfirmed_email: new_email)
        EmailConfirmationMailer.with(user: self).confirmation_email.deliver_later
        true
      else
        false
      end
    end
  end

  def resend_confirmation_email
    if pending_email_change?
      EmailConfirmationMailer.with(user: self).confirmation_email.deliver_later
      true
    else
      false
    end
  end

  def request_impersonation_for(user_id)
    impersonated = User.find(user_id)
    impersonator_support_sessions.create!(impersonated: impersonated)
  end

  def admin?
    super_admin? || role == "admin"
  end

  def display_name
    [ first_name, last_name ].compact.join(" ").presence || email
  end

  def initial
    (display_name&.first || email.first).upcase
  end

  def initials
    if first_name.present? && last_name.present?
      "#{first_name.first}#{last_name.first}".upcase
    else
      initial
    end
  end

  def show_ai_sidebar?
    show_ai_sidebar
  end

  def show_split_grouped?
    true
  end

  # Safe avatar URL helper - handles missing files gracefully.
  # This avoids 500 errors when profile images exist in DB but not in storage
  # (e.g., after migration from local to R2 storage) and uses signed URLs
  # with a short expiry so file access is controlled rather than public by default.
  def safe_avatar_url(variant = :small)
    ActiveStorage::SecureUrlService.for_attachment(
      profile_image,
      variant: variant,
      expires_in: 5.minutes,
      disposition: :inline,
      filename: profile_image.filename
    )
  end

  def ai_available?
    env_token = ENV["OPENAI_ACCESS_TOKEN"]
    db_token = Setting.find_by(var: "openai_access_token")&.value

    env_token.present? || db_token.present?
  end

  def ai_enabled?
    ai_enabled && ai_available?
  end

  # Deactivation
  validate :can_deactivate, if: -> { active_changed? && !active }
  after_update_commit :purge_later, if: -> { saved_change_to_active?(from: true, to: false) }

  def deactivate
    update active: false, email: deactivated_email
  end

  def can_deactivate
    if admin? && family.users.count > 1
      errors.add(:base, :cannot_deactivate_admin_with_other_users)
    end
  end

  def purge_later
    UserPurgeJob.perform_later(self)
  end

  def purge
    if last_user_in_family?
      family.destroy
    else
      destroy
    end
  end

  # MFA
  def setup_mfa!
    update!(
      otp_secret: ROTP::Base32.random(32),
      otp_required: false,
      otp_backup_codes: []
    )
  end

  def enable_mfa!
    update!(
      otp_required: true,
      otp_backup_codes: generate_backup_codes
    )
  end

  def disable_mfa!
    update!(
      otp_secret: nil,
      otp_required: false,
      otp_backup_codes: []
    )
  end

  def verify_otp?(code)
    return false if otp_secret.blank?
    return true if verify_backup_code?(code)
    totp.verify(code, drift_behind: 15)
  end

  def provisioning_uri
    return nil unless otp_secret.present?
    totp.provisioning_uri(email)
  end

  def onboarded?
    onboarded_at.present?
  end

  def needs_onboarding?
    !onboarded?
  end

  # Comprehensive onboarding completion check
  def onboarding_complete?
    # Simply check if user has been onboarded
    # This works for both managed and self-hosted modes
    onboarded?
  end

  # Auto-mark onboarded for self-hosted users with families (used only in specific contexts)
  def auto_mark_onboarded_if_family_exists!
    if Rails.application.config.app_mode.self_hosted? && family.present? && onboarded_at.blank?
      update_column(:onboarded_at, Time.current)
    end
  end

  # Mark user as having completed onboarding
  def mark_onboarded!
    update_column(:onboarded_at, Time.current) if onboarded_at.blank?
  end

  def account_order
    AccountOrder.find(default_account_order) || AccountOrder.default
  end

  private
    def ensure_valid_profile_image
      return unless profile_image.attached?

      unless profile_image.content_type.in?(%w[image/jpeg image/png])
        errors.add(:profile_image, "must be a JPEG or PNG")
        profile_image.purge
      end
    end

    def last_user_in_family?
      family.users.count == 1
    end

    def deactivated_email
      email.gsub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end

    def profile_image_size
      if profile_image.attached? && profile_image.byte_size > 10.megabytes
        errors.add(:profile_image, :invalid_file_size, max_megabytes: 10)
      end
    end

    def totp
      ROTP::TOTP.new(otp_secret, issuer: "Sure Finance")
    end

    def verify_backup_code?(code)
      return false if otp_backup_codes.blank?

      # Find and remove the used backup code
      if (index = otp_backup_codes.index(code))
        remaining_codes = otp_backup_codes.dup
        remaining_codes.delete_at(index)
        update_column(:otp_backup_codes, remaining_codes)
        true
      else
        false
      end
    end

    def generate_backup_codes
      8.times.map { SecureRandom.hex(4) }
    end
end
