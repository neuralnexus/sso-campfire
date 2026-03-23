module Identity
  # Handles logout for OIDC-authenticated sessions.
  # Terminates the local Campfire session and, if the provider supports
  # end_session_endpoint, returns a URI to redirect the browser for IdP logout.
  class SessionLogout
    Result = Data.define(:end_session_uri)

    def initialize(user:, session:)
      @user    = user
      @session = session
    end

    def call
      provider_id = @session[:oidc_provider_id]
      provider    = provider_id ? IdentityProvider.find_by(id: provider_id) : nil

      # Destroy all sessions for this user, not just the current one,
      # to prevent session fixation via parallel tabs.
      @user&.sessions&.destroy_all

      end_session_uri = build_end_session_uri(provider)

      Result.new(end_session_uri: end_session_uri)
    end

    private

      def build_end_session_uri(provider)
        return nil unless provider&.end_session_endpoint.present?

        uri = URI.parse(provider.end_session_endpoint)
        uri.query = URI.encode_www_form(
          post_logout_redirect_uri: Rails.application.routes.url_helpers.root_url
        )
        uri.to_s
      rescue URI::InvalidURIError
        nil
      end
  end
end
