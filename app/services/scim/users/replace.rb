module Scim
  module Users
    # Handles SCIM PUT (full replace). RFC 7644 §3.5.1.
    # Treats PUT as a bounded update of the same mutable fields as PATCH,
    # since full replacement of a user record is unsafe in a single-tenant app
    # (it would clear fields the IdP doesn't know about).
    class Replace
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

        email        = extract_email
        display_name = @payload[:displayName].presence ||
                       @payload.dig(:name, :formatted).presence
        active       = @payload.fetch(:active, true)
        external_id  = @payload[:externalId]

        ActiveRecord::Base.transaction do
          user.update!(
            name:                  display_name || user.name,
            email_address:         email || user.email_address,
            last_identity_sync_at: Time.current
          )

          ei.update!(
            scim_external_id:  external_id || ei.scim_external_id,
            email_at_link_time: email || ei.email_at_link_time,
            last_scim_sync_at: Time.current
          )

          # Handle active state change.
          if (active == false || active.to_s == "false") && ei.active?
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
          elsif (active == true || active.to_s == "true") && !ei.active?
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
          end
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
          details:          { method: "PUT" }
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

        def extract_email
          (@payload.dig(:emails, 0, :value).presence ||
           @payload[:userName].presence)&.downcase&.strip
        end
    end
  end
end
