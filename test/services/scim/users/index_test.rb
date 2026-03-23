require "test_helper"

class Scim::Users::IndexTest < ActiveSupport::TestCase
  test "filters by userName" do
    provider = create_provider
    create_identity(provider: provider, email: "alpha@example.test", external_id: "ext-alpha")
    create_identity(provider: provider, email: "beta@example.test", external_id: "ext-beta")

    result = Scim::Users::Index.new(
      provider: provider,
      params: { filter: 'userName eq "alpha@example.test"' },
      base_url: "https://campfire.example.test"
    ).call

    assert_equal 1, result[:totalResults]
    assert_equal "alpha@example.test", result[:Resources].first[:userName]
  end

  test "filters by externalId" do
    provider = create_provider
    create_identity(provider: provider, email: "gamma@example.test", external_id: "ext-gamma")
    create_identity(provider: provider, email: "delta@example.test", external_id: "ext-delta")

    result = Scim::Users::Index.new(
      provider: provider,
      params: { filter: 'externalId eq "ext-delta"' },
      base_url: "https://campfire.example.test"
    ).call

    assert_equal 1, result[:totalResults]
    assert_equal "ext-delta", result[:Resources].first[:externalId]
  end

  test "raises invalid value for unsupported filter" do
    provider = create_provider

    assert_raises(Scim::Errors::InvalidValue) do
      Scim::Users::Index.new(
        provider: provider,
        params: { filter: 'displayName co "alpha"' },
        base_url: "https://campfire.example.test"
      ).call
    end
  end

  private

    def create_provider
      IdentityProvider.create!(
        name: "Okta #{SecureRandom.hex(4)}",
        protocol: "oidc",
        issuer: "https://idp.example.test/#{SecureRandom.hex(6)}",
        discovery_url: "https://idp.example.test/.well-known/openid-configuration/#{SecureRandom.hex(6)}",
        client_id: "client-#{SecureRandom.hex(4)}",
        encrypted_client_secret: "secret-#{SecureRandom.hex(8)}",
        encrypted_client_secret_iv: SecureRandom.hex(12),
        scopes: "openid email profile",
        enabled: true
      )
    end

    def create_identity(provider:, email:, external_id:)
      user = User.create!(
        name: email.split("@").first,
        email_address: email,
        role: :member,
        status: :active,
        externally_managed: true,
        provisioning_source: "scim"
      )

      ExternalIdentity.create!(
        user: user,
        identity_provider: provider,
        provider_subject: SecureRandom.uuid,
        scim_external_id: external_id,
        scim_resource_id: SecureRandom.uuid
      )
    end
end
