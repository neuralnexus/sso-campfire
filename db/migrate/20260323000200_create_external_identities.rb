class CreateExternalIdentities < ActiveRecord::Migration[8.2]
  def change
    create_table :external_identities do |t|
      t.references :user,              null: false, foreign_key: true
      t.references :identity_provider, null: false, foreign_key: true
      t.string  :provider_subject,     null: false
      t.string  :scim_external_id
      t.string  :scim_resource_id
      t.string  :email_at_link_time
      t.string  :username_at_link_time
      t.boolean :active,               null: false, default: true
      t.boolean :externally_managed,   null: false, default: true
      t.datetime :last_authenticated_at
      t.datetime :last_scim_sync_at
      t.datetime :deprovisioned_at
      t.text    :last_claims   # JSON, serialized in model
      t.text    :metadata      # JSON, serialized in model
      t.timestamps
    end

    # Primary lookup: issuer + sub is the stable security identifier
    add_index :external_identities,
      [ :identity_provider_id, :provider_subject ],
      unique: true,
      name: "idx_external_identities_provider_subject"

    # SCIM external ID (IdP-assigned, may be absent)
    add_index :external_identities,
      [ :identity_provider_id, :scim_external_id ],
      unique: true,
      where: "scim_external_id IS NOT NULL",
      name: "idx_external_identities_provider_scim_external_id"

    # SCIM resource ID (our assigned ID, returned to IdP)
    add_index :external_identities,
      [ :identity_provider_id, :scim_resource_id ],
      unique: true,
      where: "scim_resource_id IS NOT NULL",
      name: "idx_external_identities_provider_scim_resource_id"
  end
end
