class ScimToken < ApplicationRecord
  DEFAULT_SCOPES = %w[scim:read scim:write].freeze

  serialize :scopes, coder: JSON

  belongs_to :identity_provider

  validates :token_fingerprint, presence: true, uniqueness: true
  validates :name,              presence: true

  scope :active,   -> { where(active: true) }
  scope :usable,   -> { active.where("expires_at IS NULL OR expires_at > ?", Time.current) }

  # Issues a new token. Returns [record, raw_token].
  # raw_token is the only time the plaintext value is available — it is never stored.
  def self.issue!(provider:, name:, expires_at: nil, scopes: DEFAULT_SCOPES)
    raw = SecureRandom.hex(32)
    record = create!(
      identity_provider: provider,
      name:              name,
      expires_at:        expires_at,
      scopes:            scopes,
      token_fingerprint: fingerprint(raw)
    )
    [ record, raw ]
  end

  def self.authenticate(raw_token)
    fp = fingerprint(raw_token)
    usable.find_by(token_fingerprint: fp)
  end

  def self.fingerprint(raw)
    key = Rails.application.credentials.dig(:scim_hmac_key) ||
          Rails.application.secret_key_base
    OpenSSL::HMAC.hexdigest("SHA256", key, raw)
  end

  def revoke!
    update!(active: false)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end
end
