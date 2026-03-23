module Identity
  # Refreshes OIDC discovery metadata (endpoints + JWKS URI) for all enabled
  # identity providers. Runs on a schedule so cached endpoints stay current
  # without requiring a manual admin action.
  #
  # Each provider's discovery_url is fetched and the following fields are
  # updated if they have changed:
  #   authorization_endpoint, token_endpoint, userinfo_endpoint,
  #   jwks_uri, end_session_endpoint, last_metadata_refresh_at
  #
  # Failures for individual providers are logged and do not abort the job —
  # a single unreachable IdP should not block refresh for others.
  class RefreshMetadataJob < ApplicationJob
    # Use a low-priority queue so this never contends with auth traffic.
    queue_as :low

    # Retry with exponential backoff on transient network errors.
    retry_on Timeout::Error,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Errno::ECONNRESET,
      Errno::ECONNREFUSED,
      EOFError,
      SocketError,
      wait: :polynomially_longer,
      attempts: 3

    def perform(provider_id = nil)
      providers = if provider_id
        IdentityProvider.where(id: provider_id, enabled: true)
      else
        IdentityProvider.enabled
      end

      providers.each do |provider|
        refresh_provider(provider)
      end
    end

    private

      def refresh_provider(provider)
        response = Net::HTTP.get_response(URI.parse(provider.discovery_url))

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.warn("[Identity::RefreshMetadataJob] #{provider.name}: HTTP #{response.code}")
          return
        end

        metadata = JSON.parse(response.body)

        # Validate that the fetched document still matches the configured issuer.
        # If it doesn't, log and skip — do not silently update to a different issuer.
        if metadata["issuer"].present? && metadata["issuer"] != provider.issuer
          Rails.logger.error(
            "[Identity::RefreshMetadataJob] #{provider.name}: issuer mismatch " \
            "(configured=#{provider.issuer.inspect}, got=#{metadata['issuer'].inspect}). Skipping."
          )
          return
        end

        provider.update!(
          authorization_endpoint:  metadata["authorization_endpoint"],
          token_endpoint:          metadata["token_endpoint"],
          userinfo_endpoint:       metadata["userinfo_endpoint"],
          jwks_uri:                metadata["jwks_uri"],
          end_session_endpoint:    metadata["end_session_endpoint"],
          last_metadata_refresh_at: Time.current
        )

        Rails.logger.info("[Identity::RefreshMetadataJob] #{provider.name}: refreshed OK")
      rescue JSON::ParserError => e
        Rails.logger.error("[Identity::RefreshMetadataJob] #{provider.name}: invalid JSON — #{e.message}")
      rescue Timeout::Error,
             Net::OpenTimeout,
             Net::ReadTimeout,
             Errno::ECONNRESET,
             Errno::ECONNREFUSED,
             EOFError,
             SocketError => e
        Rails.logger.warn("[Identity::RefreshMetadataJob] #{provider.name}: transient network error — #{e.message}")
        raise
      rescue => e
        Rails.logger.error("[Identity::RefreshMetadataJob] #{provider.name}: #{e.class} — #{e.message}")
      end
  end
end
