class Scim::V2::BaseController < ActionController::API
  before_action :authenticate_scim_token!
  before_action :enforce_content_type!

  rescue_from Scim::Errors::Base, with: :render_scim_error
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  private

    def authenticate_scim_token!
      raw = request.authorization.to_s.sub(/\ABearer\s+/i, "")
      @scim_token = Scim::AuthenticateToken.new(token: raw).call
    rescue Scim::Errors::Unauthorized => e
      render json: e.to_scim_response, status: :unauthorized
    end

    # SCIM requires application/scim+json or application/json on mutating requests.
    def enforce_content_type!
      return if request.get? || request.head?

      acceptable = %w[application/scim+json application/json]
      unless acceptable.any? { |ct| request.content_type&.start_with?(ct) }
        render json: {
          schemas: ["urn:ietf:params:scim:api:messages:2.0:Error"],
          detail:  "Content-Type must be application/scim+json or application/json",
          status:  "415"
        }, status: :unsupported_media_type
      end
    end

    def current_provider
      @scim_token.identity_provider
    end

    def scim_payload
      # Permit known SCIM top-level keys only. Deeper schema validation is handled
      # inside service objects.
      allowed_keys = %w[
        schemas id externalId userName displayName active name emails
        Operations members meta
      ]

      request.request_parameters.slice(*allowed_keys).with_indifferent_access
    end

    def base_url
      "#{request.protocol}#{request.host_with_port}"
    end

    def render_scim_error(error)
      render json: error.to_scim_response, status: error.status
    end

    def render_bad_request(error)
      render json: {
        schemas: ["urn:ietf:params:scim:api:messages:2.0:Error"],
        detail:  error.message,
        status:  "400"
      }, status: :bad_request
    end
end
