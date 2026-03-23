module Identity
  module Errors
    # Base for all identity subsystem errors. Controllers rescue this to
    # redirect to the failure endpoint without leaking internal detail.
    class Base < StandardError; end

    # OIDC state token missing or does not match session — possible CSRF/replay.
    class StateMismatch < Base; end

    # OIDC nonce missing or does not match stored value — possible replay.
    class NonceMismatch < Base; end

    # PKCE code_verifier does not match code_challenge stored at start.
    class PkceFailure < Base; end

    # id_token issuer does not match the configured provider issuer exactly.
    class IssuerMismatch < Base; end

    # id_token audience does not include our client_id.
    class AudienceMismatch < Base; end

    # id_token is expired or not yet valid (outside clock_skew window).
    class TokenExpired < Base; end

    # id_token failed verification (signature, issuer, audience, or format).
    class TokenInvalid < Base; end

    # email_verified claim is false or absent when require_email_verified is set.
    class EmailNotVerified < Base; end

    # An ExternalIdentity exists for this subject but is deprovisioned.
    # Requires admin reactivation before login is permitted.
    class AccountDeprovisioned < Base; end

    # A local user with the same email exists but allow_email_linking is false,
    # or the target user is a break-glass admin.
    class RelinkDenied < Base; end

    # No enabled identity provider is configured.
    class NoProviderConfigured < Base; end

    # The provider's discovery document could not be fetched or parsed.
    class DiscoveryFailed < Base; end

    # Token exchange with the IdP authorization server failed.
    class TokenExchangeFailed < Base; end

    # JIT provisioning is disabled and no existing ExternalIdentity was found.
    class JitDisabled < Base; end
  end
end
