# SCIM ServiceProviderConfig — advertises supported features to the IdP.
# RFC 7643 §5. No authentication required per spec, but we keep the
# base_controller auth so IdPs that probe this endpoint are still validated.
class Scim::V2::ServiceProviderConfigController < Scim::V2::BaseController
  def show
    render json: {
      schemas: [ "urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig" ],
      documentationUri: nil,
      patch: { supported: true },
      bulk:  { supported: false, maxOperations: 0, maxPayloadSize: 0 },
      filter: { supported: true, maxResults: 200 },
      changePassword: { supported: false },
      sort:   { supported: false },
      etag:   { supported: false },
      authenticationSchemes: [
        {
          type:        "oauthbearertoken",
          name:        "OAuth Bearer Token",
          description: "Authentication scheme using the OAuth Bearer Token standard",
          specUri:     "http://www.rfc-editor.org/info/rfc6750",
          primary:     true
        }
      ],
      meta: {
        resourceType: "ServiceProviderConfig",
        location:     "#{base_url}/scim/v2/ServiceProviderConfig"
      }
    }
  end
end
