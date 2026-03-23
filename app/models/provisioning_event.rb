class ProvisioningEvent < ApplicationRecord
  serialize :details, coder: JSON

  EVENT_TYPES = %w[
    oidc_login
    jit_provision
    scim_create
    scim_patch
    scim_replace
    scim_deactivate
    scim_reactivate
    relink_denied
    token_rotate
    token_revoke
  ].freeze

  belongs_to :identity_provider
  belongs_to :user, optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }

  scope :recent,    -> { order(created_at: :desc) }
  scope :failures,  -> { where(success: false) }
  scope :for_user,  ->(user) { where(user: user) }

  def self.record(provider:, event_type:, success:, **attrs)
    create!(
      identity_provider: provider,
      event_type:        event_type,
      success:           success,
      **attrs
    )
  rescue => e
    # Audit log failures must not break the auth flow, but should be surfaced.
    Rails.logger.error("[ProvisioningEvent] Failed to record #{event_type}: #{e.message}")
  end
end
