module Scim
  module Users
    class Index
      SUPPORTED_FILTER = /\A\s*(userName|externalId)\s+eq\s+"((?:[^"\\]|\\.)*)"(?:\s+and\s+(userName|externalId)\s+eq\s+"((?:[^"\\]|\\.)*)")?\s*\z/i

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

        start_index = [ (@params[:startIndex] || 1).to_i, 1 ].max
        count       = [ (@params[:count] || 100).to_i, 200 ].min
        offset      = start_index - 1

        total      = identities.count
        page_items = identities.offset(offset).limit(count)

        resources = page_items.map do |ei|
          Scim::UserSerializer.new(user: ei.user, external_identity: ei, base_url: @base_url).call
        end

        {
          schemas:      [ "urn:ietf:params:scim:api:messages:2.0:ListResponse" ],
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

          parsed = parse_filter!(filter)
          parsed.each do |attribute, value|
            case attribute
            when "userName"
              scope = scope.joins(:user).where(users: { email_address: value.downcase })
            when "externalId"
              scope = scope.where(scim_external_id: value)
            end
          end

          scope
        end

        def parse_filter!(filter)
          match = filter.match(SUPPORTED_FILTER)
          unless match
            raise Scim::Errors::InvalidValue,
              "Unsupported filter. Supported forms: userName eq \"...\" and externalId eq \"...\""
          end

          pairs = [ [ match[1], unescape_filter_value(match[2]) ] ]
          pairs << [ match[3], unescape_filter_value(match[4]) ] if match[3].present?
          pairs.uniq { |attribute, _value| attribute.downcase }
        end

        def unescape_filter_value(raw)
          JSON.parse("\"#{raw}\"")
        rescue JSON::ParserError
          raise Scim::Errors::InvalidValue, "Invalid escape sequence in SCIM filter"
        end
    end
  end
end
