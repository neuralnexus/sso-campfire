module Scim
  module Users
    # Handles SCIM DELETE /Users/:id (RFC 7644 §3.6).
    #
    # Hard-delete via API is never performed. DELETE is treated as a
    # soft-deactivation: the user's account is suspended, all sessions are
    # revoked, and the ExternalIdentity is marked deprovisioned. Message
    # history is preserved. An admin can reactivate the account later.
    #
    # Break-glass admins are protected and cannot be deprovisioned via SCIM.
    class Destroy
      def initialize(provider:, id:, request:)
        @provider = provider
        @id       = id
        @request  = request
      end

      def call
        ei = find_identity!

        raise Scim::Errors::ProtectedResource if ei.user.protected_from_scim?

        # Idempotent: if already deprovisioned, return success without re-running.
        unless ei.deprovisioned_at.present?
          ei.deprovision!

          ProvisioningEvent.record(
            provider:         @provider,
            event_type:       "scim_deactivate",
            user:             ei.user,
            success:          true,
            scim_resource_id: @id,
            source_ip:        @request.remote_ip,
            user_agent:       @request.user_agent,
            request_id:       @request.request_id,
            details:          { method: "DELETE" }
          )
        end
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
