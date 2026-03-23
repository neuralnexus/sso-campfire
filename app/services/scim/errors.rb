module Scim
  module Errors
    class Base < StandardError
      attr_reader :scim_type, :status

      def initialize(message = nil, scim_type: nil, status: 400)
        super(message)
        @scim_type = scim_type
        @status    = status
      end

      def to_scim_response
        {
          schemas:  [ "urn:ietf:params:scim:api:messages:2.0:Error" ],
          detail:   message,
          scimType: scim_type,
          status:   status.to_s
        }.compact
      end
    end

    class Unauthorized < Base
      def initialize(msg = "Unauthorized")
        super(msg, status: 401)
      end
    end

    class Forbidden < Base
      def initialize(msg = "Forbidden")
        super(msg, status: 403)
      end
    end

    class NotFound < Base
      def initialize(msg = "Resource not found")
        super(msg, status: 404)
      end
    end

    class Conflict < Base
      def initialize(msg = "Resource already exists")
        super(msg, scim_type: "uniqueness", status: 409)
      end
    end

    class InvalidValue < Base
      def initialize(msg = "Invalid value")
        super(msg, scim_type: "invalidValue", status: 400)
      end
    end

    class MutabilityError < Base
      def initialize(msg = "Attribute is immutable")
        super(msg, scim_type: "mutability", status: 400)
      end
    end

    class ProtectedResource < Base
      def initialize(msg = "This resource is protected and cannot be modified via SCIM")
        super(msg, status: 403)
      end
    end
  end
end
