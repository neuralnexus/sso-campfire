class IdentityProvider < ApplicationRecord
  PROTOCOLS       = %w[oidc].freeze
  ALLOWED_ALGOS   = %w[RS256 RS384 RS512 ES256 ES384 ES512].freeze
  HTTPS_SCHEMES   = %w[https].freeze

  serialize :settings, coder: JSON

  has_many :external_identities,  dependent: :restrict_with_exception
  has_many :scim_tokens,          dependent: :destroy
  has_many :group_mappings,       dependent: :destroy
  has_many :provisioning_events,  dependent: :nullify

  encrypts :encrypted_client_secret

  validates :name,                    presence: true
  validates :issuer,                  presence: true, uniqueness: true
  validates :discovery_url,           presence: true
  validates :client_id,               presence: true
  validates :encrypted_client_secret, presence: true
  validates :protocol,                inclusion: { in: PROTOCOLS }
  validate  :https_urls_only

  scope :enabled, -> { where(enabled: true) }

  def self.active_oidc
    enabled.find_by(protocol: "oidc")
  end

  def scopes_array
    scopes.split
  end

  def client_secret
    encrypted_client_secret
  end

  def client_secret=(value)
    self.encrypted_client_secret = value
    self.encrypted_client_secret_iv = SecureRandom.hex(12) if value.present?
  end

  private

    def https_urls_only
      [ issuer, discovery_url ].compact.each do |url|
        uri = URI.parse(url)
        errors.add(:base, "#{url} must use HTTPS") unless HTTPS_SCHEMES.include?(uri.scheme)
      rescue URI::InvalidURIError
        errors.add(:base, "#{url} is not a valid URL")
      end
    end

end
