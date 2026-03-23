module Scim
  # Serializes a User + ExternalIdentity pair into a SCIM 2.0 User resource.
  # The resource id is ExternalIdentity.scim_resource_id (stable, opaque to the IdP).
  class UserSerializer
    SCHEMA = "urn:ietf:params:scim:schemas:core:2.0:User".freeze

    def initialize(user:, external_identity:, base_url:)
      @user              = user
      @external_identity = external_identity
      @base_url          = base_url
    end

    def call
      {
        schemas:    [SCHEMA],
        id:         @external_identity.scim_resource_id,
        externalId: @external_identity.scim_external_id,
        userName:   @user.email_address,
        displayName: @user.name,
        name: {
          formatted: @user.name
        },
        emails: [
          { value: @user.email_address, primary: true }
        ],
        active:    @user.active?,
        meta: {
          resourceType: "User",
          created:      @external_identity.created_at.iso8601,
          lastModified: @external_identity.updated_at.iso8601,
          location:     "#{@base_url}/scim/v2/Users/#{@external_identity.scim_resource_id}"
        }
      }
    end
  end
end
