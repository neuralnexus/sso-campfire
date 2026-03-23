module Scim
  module Users
    class Show
      def initialize(provider:, id:, base_url:)
        @provider = provider
        @id       = id
        @base_url = base_url
      end

      def call
        ei = find_identity!
        Scim::UserSerializer.new(user: ei.user, external_identity: ei, base_url: @base_url).call
      end

      private

        def find_identity!
          ei = ExternalIdentity.find_by(
            identity_provider: @provider,
            scim_resource_id:  @id
          )
          # Do not reveal whether the resource belongs to a different provider.
          raise Scim::Errors::NotFound unless ei
          ei
        end
    end
  end
end
