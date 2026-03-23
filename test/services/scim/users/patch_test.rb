require "test_helper"

class Scim::Users::PatchTest < ActiveSupport::TestCase
  test "updates display name via path-based replace" do
    provider, identity = create_identity

    payload = {
      Operations: [
        { op: "replace", path: "displayName", value: "Renamed User" }
      ]
    }

    result = Scim::Users::Patch.new(
      provider: provider,
      id: identity.scim_resource_id,
      payload: payload,
      request: request_stub,
      base_url: "https://campfire.example.test"
    ).call

    assert_equal "Renamed User", identity.user.reload.name
    assert_equal "Renamed User", result[:displayName]
  end

  test "raises on immutable attribute writes" do
    provider, identity = create_identity

    payload = {
      Operations: [
        { op: "replace", path: "role", value: "administrator" }
      ]
    }

    assert_raises(Scim::Errors::MutabilityError) do
      Scim::Users::Patch.new(
        provider: provider,
        id: identity.scim_resource_id,
        payload: payload,
        request: request_stub,
        base_url: "https://campfire.example.test"
      ).call
    end
  end

  test "deactivates user when active is false" do
    provider, identity = create_identity

    payload = {
      Operations: [
        { op: "replace", path: "active", value: false }
      ]
    }

    Scim::Users::Patch.new(
      provider: provider,
      id: identity.scim_resource_id,
      payload: payload,
      request: request_stub,
      base_url: "https://campfire.example.test"
    ).call

    assert_not identity.reload.active?
    assert identity.user.reload.deactivated?
  end

  test "rejects unknown operation type" do
    provider, identity = create_identity

    payload = {
      Operations: [
        { op: "move", path: "displayName", value: "Nope" }
      ]
    }

    assert_raises(Scim::Errors::InvalidValue) do
      Scim::Users::Patch.new(
        provider: provider,
        id: identity.scim_resource_id,
        payload: payload,
        request: request_stub,
        base_url: "https://campfire.example.test"
      ).call
    end
  end

  private

    def create_identity
      provider = IdentityProvider.create!(
        name: "Okta #{SecureRandom.hex(4)}",
        protocol: "oidc",
        issuer: "https://idp.example.test/#{SecureRandom.hex(6)}",
        discovery_url: "https://idp.example.test/.well-known/openid-configuration/#{SecureRandom.hex(6)}",
        client_id: "client-#{SecureRandom.hex(4)}",
        client_secret: "secret-#{SecureRandom.hex(8)}",
        scopes: "openid email profile",
        enabled: true
      )

      user = User.create!(
        name: "SCIM User",
        email_address: "scim-#{SecureRandom.hex(4)}@example.test",
        role: :member,
        status: :active,
        externally_managed: true,
        provisioning_source: "scim"
      )

      identity = ExternalIdentity.create!(
        user: user,
        identity_provider: provider,
        provider_subject: SecureRandom.uuid,
        scim_resource_id: SecureRandom.uuid,
        active: true
      )

      [ provider, identity ]
    end

    def request_stub
      Struct.new(:remote_ip, :user_agent, :request_id).new("127.0.0.1", "Minitest", "req-#{SecureRandom.hex(4)}")
    end
end
