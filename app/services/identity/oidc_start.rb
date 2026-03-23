module Identity
  # Generates the authorization redirect URI and stores all server-side
  # anti-replay state (state, nonce, PKCE verifier) in the session.
  # Nothing is stored client-side except the session cookie.
  class OidcStart
    PKCE_METHOD = "S256".freeze

    Result = Data.define(:authorization_uri)

    def initialize(session:, provider:, request:)
      @session  = session
      @provider = provider
      @request  = request
    end

    def call
      raise Errors::NoProviderConfigured if @provider.nil? || !@provider.enabled?

      state    = SecureRandom.hex(24)
      nonce    = SecureRandom.hex(24)
      verifier = SecureRandom.hex(32)
      challenge = pkce_challenge(verifier)

      # All anti-replay state lives server-side in the encrypted session.
      @session[:oidc_state]    = state
      @session[:oidc_nonce]    = nonce
      @session[:oidc_verifier] = verifier if @provider.require_pkce?
      @session[:oidc_provider] = @provider.id

      params = {
        response_type: "code",
        client_id:     @provider.client_id,
        redirect_uri:  redirect_uri,
        scope:         @provider.scopes,
        state:         state,
        nonce:         nonce
      }

      if @provider.require_pkce?
        params[:code_challenge]        = challenge
        params[:code_challenge_method] = PKCE_METHOD
      end

      authorization_endpoint = @provider.authorization_endpoint ||
        fetch_authorization_endpoint

      uri = URI.parse(authorization_endpoint)
      uri.query = URI.encode_www_form(params)

      Result.new(authorization_uri: uri.to_s)
    end

    private

      def pkce_challenge(verifier)
        digest = OpenSSL::Digest::SHA256.digest(verifier)
        Base64.urlsafe_encode64(digest, padding: false)
      end

      def redirect_uri
        # Exact redirect URI — no dynamic overrides permitted.
        Rails.application.routes.url_helpers.callback_auth_oidc_url(
          host: @request.host_with_port,
          protocol: @request.protocol
        )
      end

      def fetch_authorization_endpoint
        response = Net::HTTP.get_response(URI.parse(@provider.discovery_url))
        JSON.parse(response.body).fetch("authorization_endpoint")
      rescue StandardError => e
        raise Errors::DiscoveryFailed, "Could not fetch authorization_endpoint: #{e.message}"
      end
  end
end
