class GroupMapping < ApplicationRecord
  ROLES = %w[member administrator].freeze

  belongs_to :identity_provider
  belongs_to :room, optional: true

  validates :role, inclusion: { in: ROLES }, allow_nil: true
  validates :external_group_id, uniqueness: { scope: :identity_provider_id }, allow_nil: true

  scope :enabled,  -> { where(enabled: true) }
  scope :ordered,  -> { order(priority: :asc) }

  # Returns the highest-priority matching mapping for a set of group identifiers.
  # Groups only act when an explicit mapping exists — no implicit name-to-role matching.
  def self.resolve_for(provider:, group_ids:)
    return [] if group_ids.blank?
    enabled
      .where(identity_provider: provider, external_group_id: group_ids)
      .ordered
  end
end
