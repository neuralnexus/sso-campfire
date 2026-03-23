# SCIM Groups endpoint (RFC 7643 §8.7.1).
#
# Groups pushed by the IdP are stored as GroupMapping records so they appear
# in the admin UI and can be assigned roles/rooms. A pushed group with no
# existing mapping is created as disabled — an admin must explicitly enable
# it and assign an effect (role or room) before it influences user access.
#
# This prevents implicit privilege escalation: receiving a group from the IdP
# does not grant any access until an admin makes a deliberate mapping decision.
class Scim::V2::GroupsController < Scim::V2::BaseController
  GROUP_SCHEMA = "urn:ietf:params:scim:schemas:core:2.0:Group".freeze

  def index
    mappings = GroupMapping
      .where(identity_provider: current_provider)
      .ordered

    resources = mappings.map { |m| serialize_group(m) }

    render json: {
      schemas:      [ "urn:ietf:params:scim:api:messages:2.0:ListResponse" ],
      totalResults: resources.size,
      startIndex:   1,
      itemsPerPage: resources.size,
      Resources:    resources
    }
  end

  def show
    mapping = find_mapping!(params[:id])
    render json: serialize_group(mapping)
  end

  # Stores the pushed group as a GroupMapping (disabled by default).
  # If a mapping for this external_group_id already exists, returns it as-is.
  # The group has no effect on user access until an admin enables it and
  # assigns a role or room in the admin UI.
  def create
    external_id  = params[:id].presence || params[:externalId].presence || SecureRandom.uuid
    display_name = params[:displayName].to_s.strip.presence || external_id

    mapping = GroupMapping.find_or_initialize_by(
      identity_provider: current_provider,
      external_group_id: external_id
    )

    if mapping.new_record?
      mapping.assign_attributes(
        external_group_name: display_name,
        enabled:             false,
        priority:            100
      )
      mapping.save!

      ProvisioningEvent.record(
        provider:    current_provider,
        event_type:  "scim_create",
        success:     true,
        status_code: 201,
        request_id:  request.request_id,
        source_ip:   request.remote_ip,
        user_agent:  request.user_agent,
        details:     { resource_type: "Group", external_group_id: external_id, display_name: display_name }
      )

      render json: serialize_group(mapping), status: :created
    else
      # Idempotent: group already known — update display name if it changed.
      mapping.update!(external_group_name: display_name) if mapping.external_group_name != display_name
      render json: serialize_group(mapping), status: :ok
    end
  end

  # PATCH: update display name only. Role/room assignment is admin-only via the UI.
  def patch
    mapping    = find_mapping!(params[:id])
    operations = Array(params[:Operations])

    operations.each do |op|
      next unless op[:op].to_s.downcase.in?(%w[replace add])
      mapping.update!(external_group_name: op[:value].to_s) if op[:path].to_s == "displayName"
    end

    render json: serialize_group(mapping.reload)
  end

  # PUT: update display name only.
  def replace
    mapping      = find_mapping!(params[:id])
    display_name = params[:displayName].to_s.strip.presence

    mapping.update!(external_group_name: display_name) if display_name.present?

    render json: serialize_group(mapping.reload)
  end

  private

    def find_mapping!(id)
      mapping = GroupMapping.find_by(
        identity_provider: current_provider,
        external_group_id: id
      )
      raise Scim::Errors::NotFound unless mapping
      mapping
    end

    def serialize_group(mapping)
      {
        schemas:     [ GROUP_SCHEMA ],
        id:          mapping.external_group_id,
        displayName: mapping.external_group_name,
        meta: {
          resourceType: "Group",
          created:      mapping.created_at.iso8601,
          lastModified: mapping.updated_at.iso8601,
          location:     "#{base_url}/scim/v2/Groups/#{mapping.external_group_id}"
        }
      }
    end
end
