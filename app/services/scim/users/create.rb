module Scim
  module Users
    # Provisions a new user via SCIM. Creates both the User record and the
    # ExternalIdentity that links it to this provider.
    #
    # If a user with the same email already exists and is not externally managed,
    # we raise Conflict rather than silently taking over a local account.
    class Create
      def initialize(provider:, payload:, request:, base_url:)
        @provider = provider
        @payload  = payload
        @request  = request
        @base_url = base_url
      end

      def call
        email        = extract_email!
        display_name = @payload[:displayName].presence || @payload.dig(:name, :formatted).presence || email.split("@").first
        external_id  = @payload[:externalId]
        active       = @payload.fetch(:active, true)

        # Reject if a local (non-externally-managed) user already holds this email.
        if (existing = User.find_by(email_address: email))
          unless existing.externally_managed?
            raise Scim::Errors::Conflict,
              "A local user with email #{email} already exists. Admin relink required."
          end
          # If already externally managed and linked to this provider, return existing.
          if (ei = ExternalIdentity.find_by(identity_provider: @provider, user: existing))
            return Scim::UserSerializer.new(user: existing, external_identity: ei, base_url: @base_url).call
          end
        end

        resource_id = SecureRandom.uuid
        user = ei = nil

        ActiveRecord::Base.transaction do
          user = User.create!(
            name:                 display_name,
            email_address:        email,
            role:                 :member,
            status:               active ? :active : :deactivated,
            externally_managed:   true,
            provisioning_source:  "scim",
            last_identity_sync_at: Time.current
          )

          ei = ExternalIdentity.create!(
            user:               user,
            identity_provider:  @provider,
            provider_subject:   resource_id,  # SCIM-provisioned users have no OIDC sub yet
            scim_external_id:   external_id,
            scim_resource_id:   resource_id,
            email_at_link_time: email,
            externally_managed: true,
            active:             active,
            last_scim_sync_at:  Time.current
          )
        end

        ProvisioningEvent.record(
          provider:         @provider,
          event_type:       "scim_create",
          user:             user,
          success:          true,
          status_code:      201,
          scim_resource_id: resource_id,
          source_ip:        @request.remote_ip,
          user_agent:       @request.user_agent,
          request_id:       @request.request_id,
          details:          { email: email, external_id: external_id }
        )

        Scim::UserSerializer.new(user: user, external_identity: ei, base_url: @base_url).call
      end

      private

        def extract_email!
          email = @payload.dig(:emails, 0, :value).presence ||
                  @payload[:userName].presence

          raise Scim::Errors::InvalidValue, "userName or emails[0].value is required" unless email
          email.downcase.strip
        end
    end
  end
end
