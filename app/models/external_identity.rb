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
      if provider_subject_changed?
        errors.add(:provider_subject, "cannot be changed after initial link")
      end
    end
end
