require "test_helper"

class Identity::OidcCallbackTest < ActiveSupport::TestCase
  test "raises when provider is missing" do
    error = assert_raises(Identity::Errors::NoProviderConfigured) do
      Identity::OidcCallback.new(
        params: { state: "state", code: "code" },
        session: { oidc_state: "state" },
        provider: nil,
        request: request_stub
      ).call
    end

    assert_match "NoProviderConfigured", error.class.name
  end

  test "raises when provider is disabled" do
    provider = provider_stub(enabled: false)

    assert_raises(Identity::Errors::NoProviderConfigured) do
      Identity::OidcCallback.new(
        params: { state: "state", code: "code" },
        session: { oidc_state: "state" },
        provider: provider,
        request: request_stub
      ).call
    end
  end

  test "raises state mismatch before network calls" do
    provider = provider_stub

    assert_raises(Identity::Errors::StateMismatch) do
      Identity::OidcCallback.new(
        params: { state: "wrong", code: "code" },
        session: { oidc_state: "expected" },
        provider: provider,
        request: request_stub
      ).call
    end
  end

  test "raises when cached token endpoint metadata is missing" do
    provider = provider_stub(token_endpoint: nil)

    error = assert_raises(Identity::Errors::DiscoveryFailed) do
      Identity::OidcCallback.new(
        params: { state: "state", code: "code" },
        session: { oidc_state: "state", oidc_nonce: "nonce" },
        provider: provider,
        request: request_stub
      ).call
    end

    assert_match "token_endpoint", error.message
  end

  private

    def provider_stub(enabled: true, token_endpoint: "https://idp.example.test/token")
      Struct.new(
        :id,
        :enabled,
        :token_endpoint,
        :jwks_uri,
        :client_id,
        :encrypted_client_secret,
        :issuer,
        :clock_skew_seconds,
        :claim_email_verified,
        :claim_sub,
        :claim_groups,
        :scopes,
        :userinfo_endpoint,
        keyword_init: true
      ) do
        def enabled?
          enabled
        end

        def require_pkce?
          false
        end

        def require_email_verified?
          false
        end
      end.new(
        id: 1,
        enabled: enabled,
        token_endpoint: token_endpoint,
        jwks_uri: "https://idp.example.test/jwks",
        client_id: "client-id",
        encrypted_client_secret: "secret",
        issuer: "https://idp.example.test",
        clock_skew_seconds: 60,
        claim_email_verified: "email_verified",
        claim_sub: "sub",
        claim_groups: "groups",
        scopes: "openid email profile",
        userinfo_endpoint: nil
      )
    end

    def request_stub
      Struct.new(:host_with_port, :protocol, :remote_ip, :user_agent, :request_id).new(
        "campfire.example.test",
        "https://",
        "127.0.0.1",
        "Minitest",
        "req-#{SecureRandom.hex(4)}"
      )
    end
end
