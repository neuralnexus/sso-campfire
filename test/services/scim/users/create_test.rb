require "test_helper"

class Scim::Users::CreateTest < ActiveSupport::TestCase
  test "creates externally managed user and identity" do
    provider = create_provider

    payload = {
      userName: "new-user@example.test",
      displayName: "New User",
      externalId: "idp-external-123",
      active: true
    }

    result = Scim::Users::Create.new(
      provider: provider,
      payload: payload,
      request: request_stub,
      base_url: "https://campfire.example.test"
    ).call

    user = User.find_by!(email_address: "new-user@example.test")
    identity = ExternalIdentity.find_by!(identity_provider: provider, user: user)

    assert_equal "new-user@example.test", result[:userName]
    assert_equal "idp-external-123", result[:externalId]
    assert user.externally_managed?
    assert_equal "scim", user.provisioning_source
    assert_equal identity.scim_resource_id, identity.provider_subject
  end

  test "returns conflict when local user already exists" do
    provider = create_provider

    error = assert_raises(Scim::Errors::Conflict) do
      Scim::Users::Create.new(
        provider: provider,
        payload: { userName: users(:david).email_address },
        request: request_stub,
        base_url: "https://campfire.example.test"
      ).call
    end

    assert_match "local user", error.message
  end

  test "returns conflict when externally managed user is linked to another provider" do
    provider_a = create_provider
    provider_b = create_provider
    user = User.create!(
      name: "Externally Managed",
      email_address: "external@example.test",
      role: :member,
      status: :active,
      externally_managed: true,
      provisioning_source: "scim"
    )
    ExternalIdentity.create!(
      user: user,
      identity_provider: provider_a,
      provider_subject: SecureRandom.uuid,
      scim_external_id: "other-provider"
    )

    error = assert_raises(Scim::Errors::Conflict) do
      Scim::Users::Create.new(
        provider: provider_b,
        payload: { userName: "external@example.test" },
        request: request_stub,
        base_url: "https://campfire.example.test"
      ).call
    end

    assert_match "different identity provider", error.message
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

    def request_stub
      Struct.new(:remote_ip, :user_agent, :request_id).new("127.0.0.1", "Minitest", "req-#{SecureRandom.hex(4)}")
    end
end
