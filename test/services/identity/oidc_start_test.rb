require "test_helper"

class Identity::OidcStartTest < ActiveSupport::TestCase
  test "builds authorization URI and stores anti-replay session state" do
    provider = create_provider(
      authorization_endpoint: "https://idp.example.test/oauth2/v1/authorize",
      require_pkce: true
    )
    session = {}

    result = Identity::OidcStart.new(
      session: session,
      provider: provider,
      request: request_stub
    ).call

    uri = URI.parse(result.authorization_uri)
    params = URI.decode_www_form(uri.query).to_h

    assert_equal "https://idp.example.test/oauth2/v1/authorize", "#{uri.scheme}://#{uri.host}#{uri.path}"
    assert_equal provider.client_id, params["client_id"]
    assert_equal "code", params["response_type"]
    assert_equal "https://campfire.example.test/auth/oidc/callback", params["redirect_uri"]
    assert_equal session[:oidc_state], params["state"]
    assert_equal session[:oidc_nonce], params["nonce"]
    assert_equal "S256", params["code_challenge_method"]
    assert session[:oidc_verifier].present?
    assert_equal provider.id, session[:oidc_provider]
  end

  test "fetches authorization endpoint from discovery document when endpoint is blank" do
    provider = create_provider(authorization_endpoint: nil)
    session = {}

    stub_request(:get, provider.discovery_url).to_return(
      status: 200,
      body: { authorization_endpoint: "https://idp.example.test/discovered/auth" }.to_json,
      headers: { "Content-Type" => "application/json" }
    )

    result = Identity::OidcStart.new(
      session: session,
      provider: provider,
      request: request_stub
    ).call

    uri = URI.parse(result.authorization_uri)
    assert_equal "https://idp.example.test/discovered/auth", "#{uri.scheme}://#{uri.host}#{uri.path}"
  end

  test "wraps discovery errors" do
    provider = create_provider(authorization_endpoint: nil)

    stub_request(:get, provider.discovery_url).to_raise(SocketError.new("no route to host"))

    error = assert_raises(Identity::Errors::DiscoveryFailed) do
      Identity::OidcStart.new(
        session: {},
        provider: provider,
        request: request_stub
      ).call
    end

    assert_match "Could not fetch authorization_endpoint", error.message
  end

  private

    def create_provider(authorization_endpoint: "https://idp.example.test/oauth2/v1/authorize", require_pkce: true)
      IdentityProvider.create!(
        name: "Okta #{SecureRandom.hex(4)}",
        protocol: "oidc",
        issuer: "https://idp.example.test/#{SecureRandom.hex(6)}",
        discovery_url: "https://idp.example.test/.well-known/openid-configuration/#{SecureRandom.hex(6)}",
        client_id: "client-#{SecureRandom.hex(4)}",
        encrypted_client_secret: "secret-#{SecureRandom.hex(8)}",
        encrypted_client_secret_iv: SecureRandom.hex(12),
        scopes: "openid email profile",
        enabled: true,
        require_pkce: require_pkce,
        authorization_endpoint: authorization_endpoint
      )
    end

    def request_stub
      Struct.new(:host_with_port, :protocol).new("campfire.example.test", "https://")
    end
end
