module Identity
  # Resolves an OIDC claim set to a Campfire User, creating or updating as needed.
  #
  # Linking rules (in order):
  #   1. Find existing ExternalIdentity by (provider, sub) — the stable identifier.
  #   2. If deprovisioned, deny login until admin reactivates.
  #   3. If not found and JIT is enabled, attempt email linking (if configured)
  #      or create a new user.
  #   4. Never link to a break-glass admin account.
  #   5. Never auto-link by email unless allow_email_linking is explicitly set
  #      AND email_verified is true AND no other ExternalIdentity exists for
  #      that email+provider combination.
  class UserLinker
    def initialize(provider:, claims:, request: nil)
      @provider = provider
      @claims   = claims
      @request  = request
    end

    def call
      sub   = @claims.fetch(@provider.claim_sub)
      email = @claims[@provider.claim_email]

      external_identity = ExternalIdentity.find_by(
        identity_provider: @provider,
        provider_subject:  sub
      )

      if external_identity
        return handle_existing(external_identity, email)
      end

      # No existing link — attempt JIT provisioning.
      raise Errors::JitDisabled unless @provider.jit_provisioning?

      user = find_linkable_local_user(email)

      if user
        link_existing_user(user, sub, email)
      else
        create_jit_user(sub, email)
      end
    end

    private

      def handle_existing(external_identity, email)
        if external_identity.deprovisioned_at.present? || !external_identity.active?
          raise Errors::AccountDeprovisioned,
            "Account is deprovisioned. Contact an administrator to reactivate."
        end

        user = external_identity.user

        # Sync mutable profile fields from claims on each login.
        sync_profile(user, external_identity)

        user
      end

      # Finds a local user eligible for email-based linking.
      # Conditions that must ALL be true:
      #   - provider has allow_email_linking enabled
      #   - email claim is present and verified
      #   - target user is not a break-glass admin
      #   - no other ExternalIdentity already links this provider to that user
      def find_linkable_local_user(email)
        return nil unless @provider.allow_email_linking?
        return nil unless email.present?
        return nil unless email_verified?

        user = User.find_by(email_address: email)
        return nil unless user
        return nil if user.break_glass_admin?

        # Reject if this user already has a different external identity for this provider.
        if ExternalIdentity.exists?(identity_provider: @provider, user: user)
          ProvisioningEvent.record(
            provider:    @provider,
            event_type:  "relink_denied",
            user:        user,
            success:     false,
            details:     { reason: "user already linked to a different subject for this provider" }
          )
          raise Errors::RelinkDenied,
            "User already has an external identity for this provider. Admin relink required."
        end

        user
      end

      def link_existing_user(user, sub, email)
        ExternalIdentity.create!(
          user:              user,
          identity_provider: @provider,
          provider_subject:  sub,
          email_at_link_time: email,
          externally_managed: true,
          last_claims:       @claims
        )

        user.update!(
          externally_managed:   true,
          provisioning_source:  "oidc_jit",
          last_identity_sync_at: Time.current
        )

        ProvisioningEvent.record(
          provider:         @provider,
          event_type:       "jit_provision",
          user:             user,
          success:          true,
          external_subject: sub,
          details:          { method: "email_link", email: email }
        )

        user
      end

      def create_jit_user(sub, email)
        name  = @claims[@provider.claim_name].presence || email&.split("@")&.first || "User"
        email = email.presence

        user = nil

        ActiveRecord::Base.transaction do
          user = User.create!(
            name:                 name,
            email_address:        email,
            role:                 :member,
            status:               :active,
            externally_managed:   true,
            provisioning_source:  "oidc_jit",
            last_identity_sync_at: Time.current
          )

          ExternalIdentity.create!(
            user:               user,
            identity_provider:  @provider,
            provider_subject:   sub,
            email_at_link_time: email,
            externally_managed: true,
            last_claims:        @claims,
            last_authenticated_at: Time.current
          )
        end

        ProvisioningEvent.record(
          provider:         @provider,
          event_type:       "jit_provision",
          user:             user,
          success:          true,
          external_subject: sub,
          details:          { method: "create", email: email }
        )

        apply_group_mappings(user)

        user
      end

      def sync_profile(user, external_identity)
        name = @claims[@provider.claim_name].presence

        updates = { last_identity_sync_at: Time.current }
        updates[:name] = name if name.present? && user.externally_managed?

        user.update!(updates) if updates.any?

        external_identity.update!(
          last_claims:          @claims,
          last_authenticated_at: Time.current
        )

        apply_group_mappings(user)
      end

      # Applies explicit group→role/room mappings from OIDC groups claim.
      # Raw group names do nothing without a configured GroupMapping record.
      def apply_group_mappings(user)
        group_ids = Array(@claims[@provider.claim_groups]).compact
        return if group_ids.empty?

        mappings = GroupMapping.resolve_for(provider: @provider, group_ids: group_ids)
        return if mappings.empty?

        mappings.each do |mapping|
          if mapping.role.present?
            target_role = mapping.role.to_sym
            user.update!(role: target_role) if user.role.to_sym != target_role
          end

          if mapping.room_id.present?
            room = Room.find_by(id: mapping.room_id)
            room&.memberships&.find_or_create_by(user: user)
          end
        end
      end

      def email_verified?
        val = @claims[@provider.claim_email_verified]
        val == true || val == "true"
      end
  end
end
