class ExternalIdentity < ApplicationRecord
  serialize :last_claims, coder: JSON
  serialize :metadata,    coder: JSON

  belongs_to :user
  belongs_to :identity_provider

  validates :provider_subject, presence: true
  validates :provider_subject, uniqueness: { scope: :identity_provider_id }
  validate  :subject_immutable, on: :update

  scope :active,   -> { where(active: true) }
  scope :inactive, -> { where(active: false) }

  def deprovision!
    update!(
      active: false,
      deprovisioned_at: Time.current,
      externally_managed: true
    )
    # Revoke all active sessions for this user so a deprovisioned account
    # cannot continue using an existing cookie.
    user.sessions.destroy_all
    user.update!(status: :deactivated, disabled_at: Time.current)
  end

  def reactivate!
    update!(active: true, deprovisioned_at: nil)
    user.update!(status: :active, disabled_at: nil)
  end

  private

    # provider_subject is a stable security identifier (issuer+sub pair).
    # Changing it after link would silently transfer identity ownership.
    def subject_immutable
      return unless provider_subject_changed?

      # SCIM-provisioned identities may be created before the user has completed
      # an OIDC login. Allow a one-time transition from the SCIM placeholder
      # subject (scim_resource_id) to the first verified OIDC subject.
      old_subject, _new_subject = provider_subject_change_to_be_saved
      allow_scim_bootstrap_transition =
        scim_resource_id.present? &&
        old_subject == scim_resource_id &&
        last_authenticated_at.blank?

      unless allow_scim_bootstrap_transition
        errors.add(:provider_subject, "cannot be changed after initial link")
      end
    end
end
