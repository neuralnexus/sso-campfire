class Scim::V2::ResourceTypesController < Scim::V2::BaseController
  def index
    render json: {
      schemas:      [ "urn:ietf:params:scim:api:messages:2.0:ListResponse" ],
      totalResults: 2,
      Resources: [
        {
          schemas:      [ "urn:ietf:params:scim:schemas:core:2.0:ResourceType" ],
          id:           "User",
          name:         "User",
          endpoint:     "/Users",
          schema:       "urn:ietf:params:scim:schemas:core:2.0:User",
          meta: { resourceType: "ResourceType", location: "#{base_url}/scim/v2/ResourceTypes/User" }
        },
        {
          schemas:      [ "urn:ietf:params:scim:schemas:core:2.0:ResourceType" ],
          id:           "Group",
          name:         "Group",
          endpoint:     "/Groups",
          schema:       "urn:ietf:params:scim:schemas:core:2.0:Group",
          meta: { resourceType: "ResourceType", location: "#{base_url}/scim/v2/ResourceTypes/Group" }
        }
      ]
    }
  end
end
