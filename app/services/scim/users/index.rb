module Scim
  module Users
    class Index
      def initialize(provider:, params:, base_url:)
        @provider = provider
        @params   = params
        @base_url = base_url
      end

      def call
        identities = ExternalIdentity
          .where(identity_provider: @provider)
          .includes(:user)
          .order(:id)

        identities = apply_filter(identities)

        start_index = [(@params[:startIndex] || 1).to_i, 1].max
        count       = [(@params[:count] || 100).to_i, 200].min
        offset      = start_index - 1

        total      = identities.count
        page_items = identities.offset(offset).limit(count)

        resources = page_items.map do |ei|
          Scim::UserSerializer.new(user: ei.user, external_identity: ei, base_url: @base_url).call
        end

        {
          schemas:      ["urn:ietf:params:scim:api:messages:2.0:ListResponse"],
          totalResults: total,
          startIndex:   start_index,
          itemsPerPage: count,
          Resources:    resources
        }
      end

      private

        # Supports basic SCIM filter: userName eq "..." and externalId eq "..."
        def apply_filter(scope)
          filter = @params[:filter].to_s.strip
          return scope if filter.blank?

          if (m = filter.match(/\buserName\s+eq\s+"([^"]+)"/i))
            email = m[1]
            scope = scope.joins(:user).where(users: { email_address: email })
          end

          if (m = filter.match(/\bexternalId\s+eq\s+"([^"]+)"/i))
            scope = scope.where(scim_external_id: m[1])
          end

          scope
        end
    end
  end
end
