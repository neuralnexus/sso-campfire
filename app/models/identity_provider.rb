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
  validate  :issuer_matches_discovery_metadata, if: :enabled?

  scope :enabled, -> { where(enabled: true) }

  def self.active_oidc
    enabled.find_by(protocol: "oidc")
  end

  def scopes_array
    scopes.split
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

    # Fetches the discovery document and verifies the issuer claim matches exactly.
    # Prevents a misconfigured or spoofed discovery_url from silently accepting
    # tokens from a different issuer.
    def issuer_matches_discovery_metadata
      return if discovery_url.blank? || issuer.blank?

      response = Net::HTTP.get_response(URI.parse(discovery_url))
      metadata = JSON.parse(response.body)

      unless metadata["issuer"] == issuer
        errors.add(:issuer, "does not match issuer in discovery document (got #{metadata['issuer'].inspect})")
      end
    rescue => e
      errors.add(:discovery_url, "could not be fetched: #{e.message}")
    end
end
