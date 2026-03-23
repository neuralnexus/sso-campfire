module Scim
  # Authenticates a raw SCIM bearer token presented in the Authorization header.
  # Raises Scim::Errors::Unauthorized if the token is absent, expired, or revoked.
  class AuthenticateToken
    def initialize(token:)
      @token = token.to_s.strip
    end

    def call
      raise Scim::Errors::Unauthorized, "Missing bearer token" if @token.blank?

      scim_token = ScimToken.authenticate(@token)

      raise Scim::Errors::Unauthorized, "Invalid or expired token" unless scim_token

      scim_token.touch(:last_used_at)
      scim_token
    end
  end
end
