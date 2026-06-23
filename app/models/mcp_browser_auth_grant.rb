class McpBrowserAuthGrant < ApplicationRecord
  class InvalidGrantError < StandardError; end

  CODE_TTL = 2.minutes
  LOCAL_CALLBACK_HOSTS = %w[127.0.0.1 localhost ::1].freeze

  belongs_to :user

  validates :code_digest, :callback_url, :expires_at, presence: true
  validate :callback_url_is_localhost

  def self.issue_for!(user:, callback_url:, device_label:)
    code = SecureRandom.urlsafe_base64(32)
    grant = create!(
      user: user,
      callback_url: callback_url,
      device_label: device_label.presence || "Codex MCP",
      code_digest: digest_code(code),
      expires_at: CODE_TTL.from_now
    )

    [grant, code]
  end

  def self.redeem!(code:)
    grant = find_by(code_digest: digest_code(code.to_s))
    raise InvalidGrantError, "Código inválido ou expirado" unless grant

    grant.with_lock do
      raise InvalidGrantError, "Código inválido ou expirado" unless grant.redeemable?

      grant.update!(used_at: Time.current)
      MobileSession.issue_for!(
        user: grant.user,
        platform: "mcp",
        device_label: grant.device_label.presence || "Codex MCP"
      )
    end
  end

  def self.digest_code(code)
    OpenSSL::Digest::SHA256.hexdigest(code.to_s)
  end

  def redeemable?
    used_at.blank? && expires_at.future?
  end

  private

  def callback_url_is_localhost
    uri = URI.parse(callback_url.to_s)
    host = uri.host.to_s.delete_prefix("[").delete_suffix("]")
    return if uri.scheme == "http" && LOCAL_CALLBACK_HOSTS.include?(host) && uri.port.present?

    errors.add(:callback_url, "deve apontar para localhost")
  rescue URI::InvalidURIError
    errors.add(:callback_url, "é inválida")
  end
end
