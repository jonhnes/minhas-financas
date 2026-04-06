class MobileSession < ApplicationRecord
  ACCESS_TOKEN_TTL = 15.minutes
  REFRESH_TOKEN_TTL = 30.days
  LAST_USED_AT_WRITE_INTERVAL = 5.minutes

  belongs_to :user

  validates :access_token_digest, :refresh_token_digest, :expires_at, :refresh_expires_at, presence: true

  scope :active, -> { where(revoked_at: nil) }

  def self.issue_for!(user:, platform: nil, device_label: nil)
    access_token = generate_token
    refresh_token = generate_token
    session = create!(
      user: user,
      platform: platform.presence,
      device_label: device_label.presence,
      access_token_digest: digest_token(access_token),
      refresh_token_digest: digest_token(refresh_token),
      expires_at: ACCESS_TOKEN_TTL.from_now,
      refresh_expires_at: REFRESH_TOKEN_TTL.from_now,
      last_used_at: Time.current
    )

    {
      session: session,
      access_token: access_token,
      refresh_token: refresh_token
    }
  end

  def self.authenticate_access_token(token)
    return if token.blank?

    session = active.find_by(access_token_digest: digest_token(token))
    return unless session&.access_token_active?

    session.touch_last_used_at!
    session
  end

  def self.find_by_refresh_token(token)
    return if token.blank?

    session = active.find_by(refresh_token_digest: digest_token(token))
    return unless session&.refresh_token_active?

    session
  end

  def self.digest_token(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end

  def self.generate_token
    SecureRandom.urlsafe_base64(48)
  end

  def access_token_active?
    revoked_at.blank? && expires_at.future? && refresh_expires_at.future?
  end

  def refresh_token_active?
    revoked_at.blank? && refresh_expires_at.future?
  end

  def rotate_tokens!
    access_token = self.class.generate_token
    refresh_token = self.class.generate_token

    update!(
      access_token_digest: self.class.digest_token(access_token),
      refresh_token_digest: self.class.digest_token(refresh_token),
      expires_at: self.class::ACCESS_TOKEN_TTL.from_now,
      refresh_expires_at: self.class::REFRESH_TOKEN_TTL.from_now,
      last_used_at: Time.current
    )

    {
      access_token: access_token,
      refresh_token: refresh_token
    }
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def touch_last_used_at!
    return if last_used_at.present? && last_used_at > LAST_USED_AT_WRITE_INTERVAL.ago

    touch(:last_used_at)
  end
end
