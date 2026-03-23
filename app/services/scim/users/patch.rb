module Scim
  module Users
    # Applies a SCIM PATCH (RFC 7644 §3.5.2) to a provisioned user.
    #
    # Only an explicit allowlist of attributes may be mutated. Attempts to
    # modify id, provider_subject, break_glass_admin, or role via SCIM are
    # rejected. Deactivation is the only destructive operation and is soft.
    class Patch
      # Attributes SCIM is permitted to write.
      MUTABLE_ATTRS = %w[displayName active emails userName].freeze

      def initialize(provider:, id:, payload:, request:, base_url:)
        @provider = provider
        @id       = id
        @payload  = payload
        @request  = request
        @base_url = base_url
      end

      def call
        ei   = find_identity!
        user = ei.user

        raise Scim::Errors::ProtectedResource if user.protected_from_scim?

        operations = Array(@payload[:Operations])
        raise Scim::Errors::InvalidValue, "Operations array is required" if operations.empty?

        ActiveRecord::Base.transaction do
          operations.each { |op| apply_operation!(user, ei, op) }
          ei.update!(last_scim_sync_at: Time.current)
        end

        ProvisioningEvent.record(
          provider:         @provider,
          event_type:       "scim_patch",
          user:             user,
          success:          true,
          scim_resource_id: @id,
          source_ip:        @request.remote_ip,
          user_agent:       @request.user_agent,
          request_id:       @request.request_id,
          details:          { ops: operations.map { |o| o[:op] } }
        )

        Scim::UserSerializer.new(user: user.reload, external_identity: ei.reload, base_url: @base_url).call
      end

      private

        def find_identity!
          ei = ExternalIdentity.find_by(
            identity_provider: @provider,
            scim_resource_id:  @id
          )
          raise Scim::Errors::NotFound unless ei
          ei
        end

        def apply_operation!(user, ei, op)
          op_name = op[:op].to_s.downcase
          path    = op[:path].to_s
          value   = op[:value]

          case op_name
          when "replace", "add"
            apply_replace(user, ei, path, value)
          when "remove"
            # SCIM remove on users is not supported — use active=false to deactivate.
            raise Scim::Errors::InvalidValue, "remove operations are not supported on User resources"
          else
            raise Scim::Errors::InvalidValue, "Unknown op: #{op_name}"
          end
        end

        def apply_replace(user, ei, path, value)
          # Handle both path-based and value-map forms.
          if path.blank? && value.is_a?(Hash)
            value.each { |k, v| apply_single(user, ei, k.to_s, v) }
          else
            apply_single(user, ei, path, value)
          end
        end

        def apply_single(user, ei, attr, value)
          case attr
          when "active"
            set_active(user, ei, value)
          when "displayName"
            user.update!(name: value.to_s) if user.externally_managed?
          when "userName", "emails"
            # userName changes are accepted but only update the stored email.
            # The security identifier (provider_subject) is never changed here.
            new_email = attr == "emails" ? Array(value).first&.dig("value") : value.to_s
            user.update!(email_address: new_email.to_s.downcase.strip) if new_email.present?
            ei.update!(email_at_link_time: new_email)
          when "externalId"
            ei.update!(scim_external_id: value.to_s)
          else
            guard_immutable!(attr)
          end
        end

        def set_active(user, ei, value)
          active = value == true || value.to_s == "true"

          if active
            ei.reactivate!
            ProvisioningEvent.record(
              provider:    @provider,
              event_type:  "scim_reactivate",
              user:        user,
              success:     true,
              scim_resource_id: @id,
              source_ip:   @request.remote_ip,
              request_id:  @request.request_id
            )
          else
            ei.deprovision!
            ProvisioningEvent.record(
              provider:    @provider,
              event_type:  "scim_deactivate",
              user:        user,
              success:     true,
              scim_resource_id: @id,
              source_ip:   @request.remote_ip,
              request_id:  @request.request_id
            )
          end
        end

        def guard_immutable!(attr)
          immutable = %w[id externalId schemas meta break_glass_admin role]
          if immutable.include?(attr)
            raise Scim::Errors::MutabilityError, "#{attr} is immutable via SCIM"
          end
          # Unknown attributes are silently ignored per RFC 7644 §3.5.2.
        end
    end
  end
end
