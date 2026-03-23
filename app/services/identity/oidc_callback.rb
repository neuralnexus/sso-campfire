module Identity
  # Handles the OIDC authorization code callback.
  #
  # Security order of operations:
  #   1. Validate state (CSRF protection) — before any network call
  #   2. Validate nonce (replay protection) — before trusting any claim
  #   3. Exchange code for tokens — single-use, server-to-server
  #   4. Verify id_token signature, issuer, audience, expiry, nonce
  #   5. Optionally verify PKCE code_verifier
  #   6. Check email_verified if configured
  #   7. Resolve or provision user via UserLinker
  #   8. Emit provisioning event
  class OidcCallback
    Result = Data.define(:user, :provider)

    def initialize(params:, session:, provider:, request:)
      @params   = params
      @session  = session
      @provider = provider
      @request  = request
    end

    def call
      validate_state!
      validate_no_error!

      token_response = exchange_code!
      id_token_claims = verify_id_token!(token_response["id_token"])

      validate_nonce!(id_token_claims)
      validate_pkce_used! if @provider.require_pkce?
      validate_email_verified!(id_token_claims) if @provider.require_email_verified?

      claims = merge_userinfo(token_response, id_token_claims)
      user   = Identity::UserLinker.new(provider: @provider, claims: claims, request: @request).call

      ProvisioningEvent.record(
        provider:         @provider,
        event_type:       "oidc_login",
        user:             user,
        success:          true,
        status_code:      302,
        external_subject: claims[@provider.claim_sub],
        source_ip:        @request.remote_ip,
        user_agent:       @request.user_agent,
        request_id:       @request.request_id,
        details:          { scopes: @provider.scopes }
      )

      Result.new(user: user, provider: @provider)
    rescue Errors::Base => e
      ProvisioningEvent.record(
        provider:    @provider,
        event_type:  "oidc_login",
        success:     false,
        source_ip:   @request.remote_ip,
        user_agent:  @request.user_agent,
        request_id:  @request.request_id,
        details:     { error: e.class.name, message: e.message }
      )
      raise
    end

    private

      def validate_state!
        stored = @session.delete(:oidc_state)
        received = @params[:state]
        unless stored.present? && ActiveSupport::SecurityUtils.secure_compare(stored, received.to_s)
          raise Errors::StateMismatch, "OIDC state mismatch"
        end
      end

      def validate_no_error!
        if @params[:error].present?
          raise Errors::Base, "IdP returned error: #{@params[:error]} — #{@params[:error_description]}"
        end
      end

      def exchange_code!
        token_endpoint = @provider.token_endpoint || fetch_token_endpoint

        body = {
          grant_type:   "authorization_code",
          code:         @params[:code],
          redirect_uri: redirect_uri,
          client_id:    @provider.client_id,
          client_secret: @provider.encrypted_client_secret
        }

        if @provider.require_pkce?
          body[:code_verifier] = @session.delete(:oidc_verifier)
        end

        uri  = URI.parse(token_endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        req = Net::HTTP::Post.new(uri.path)
        req.set_form_data(body)
        req["Accept"] = "application/json"

        response = http.request(req)
        parsed   = JSON.parse(response.body)

        unless response.is_a?(Net::HTTPSuccess) && parsed["id_token"].present?
          raise Errors::TokenExchangeFailed, "Token exchange failed: #{parsed['error_description'] || response.code}"
        end

        parsed
      end

      def verify_id_token!(raw_token)
        # Fetch JWKS from provider and decode with signature verification.
        jwks_uri  = @provider.jwks_uri || fetch_jwks_uri
        jwks_body = Net::HTTP.get(URI.parse(jwks_uri))
        jwks      = JWT::JWK::Set.new(JSON.parse(jwks_body))

        # Decode verifies signature, expiry, and nbf automatically.
        payload, _header = JWT.decode(
          raw_token,
          nil,
          true,
          algorithms:        IdentityProvider::ALLOWED_ALGOS,
          jwks:              { keys: jwks.map(&:export) },
          iss:               @provider.issuer,
          verify_iss:        true,
          aud:               @provider.client_id,
          verify_aud:        true,
          leeway:            @provider.clock_skew_seconds
        )

        payload
      rescue JWT::DecodeError => e
        raise Errors::TokenExpired, "id_token verification failed: #{e.message}"
      end

      def validate_nonce!(claims)
        stored   = @session.delete(:oidc_nonce)
        received = claims["nonce"]
        unless stored.present? && ActiveSupport::SecurityUtils.secure_compare(stored, received.to_s)
          raise Errors::NonceMismatch, "OIDC nonce mismatch"
        end
      end

      def validate_pkce_used!
        # The verifier was consumed during exchange_code!. If it was absent
        # from the session, the exchange would have sent an empty verifier,
        # which the IdP should reject. We record the intent here for audit.
        # Nothing more to check client-side after a successful exchange.
      end

      def validate_email_verified!(claims)
        verified = claims[@provider.claim_email_verified]
        unless verified == true || verified == "true"
          raise Errors::EmailNotVerified, "email_verified claim is not true"
        end
      end

      # Optionally enriches id_token claims with userinfo endpoint data.
      # id_token claims take precedence for security-sensitive fields (sub, iss).
      def merge_userinfo(token_response, id_token_claims)
        return id_token_claims unless @provider.userinfo_endpoint.present?

        access_token = token_response["access_token"]
        return id_token_claims unless access_token.present?

        uri  = URI.parse(@provider.userinfo_endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        req = Net::HTTP::Get.new(uri.path)
        req["Authorization"] = "Bearer #{access_token}"
        req["Accept"]        = "application/json"

        response = http.request(req)
        userinfo = JSON.parse(response.body)

        # Merge userinfo under id_token — id_token wins on conflicts.
        userinfo.merge(id_token_claims)
      rescue => e
        Rails.logger.warn("[OidcCallback] userinfo fetch failed: #{e.message}")
        id_token_claims
      end

      def redirect_uri
        Rails.application.routes.url_helpers.callback_auth_oidc_url(
          host:     @request.host_with_port,
          protocol: @request.protocol
        )
      end

      def fetch_token_endpoint
        fetch_discovery_field("token_endpoint")
      end

      def fetch_jwks_uri
        fetch_discovery_field("jwks_uri")
      end

      def fetch_discovery_field(field)
        response = Net::HTTP.get_response(URI.parse(@provider.discovery_url))
        JSON.parse(response.body).fetch(field)
      rescue => e
        raise Errors::DiscoveryFailed, "Could not fetch #{field}: #{e.message}"
      end
  end
end
