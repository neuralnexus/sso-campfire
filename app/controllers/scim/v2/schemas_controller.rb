class Scim::V2::SchemasController < Scim::V2::BaseController
  def index
    render json: {
      schemas:      ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
      totalResults: 1,
      Resources: [
        {
          id:          "urn:ietf:params:scim:schemas:core:2.0:User",
          name:        "User",
          description: "User Account",
          attributes:  user_attributes,
          meta: { resourceType: "Schema", location: "#{base_url}/scim/v2/Schemas/urn:ietf:params:scim:schemas:core:2.0:User" }
        }
      ]
    }
  end

  private

    def user_attributes
      [
        { name: "userName",    type: "string",  required: true,  mutability: "readWrite", returned: "default", uniqueness: "server" },
        { name: "displayName", type: "string",  required: false, mutability: "readWrite", returned: "default" },
        { name: "active",      type: "boolean", required: false, mutability: "readWrite", returned: "default" },
        { name: "emails",      type: "complex", required: false, mutability: "readWrite", returned: "default", multiValued: true,
          subAttributes: [
            { name: "value",   type: "string",  required: false, mutability: "readWrite", returned: "default" },
            { name: "primary", type: "boolean", required: false, mutability: "readWrite", returned: "default" }
          ]
        }
      ]
    end
end
