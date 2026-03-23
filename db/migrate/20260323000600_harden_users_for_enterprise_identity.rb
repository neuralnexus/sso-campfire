class HardenUsersForEnterpriseIdentity < ActiveRecord::Migration[8.2]
  def change
    change_table :users do |t|
      # break_glass_admin: excluded from SCIM deactivation and OIDC-required enforcement.
      # Set only on the first-run administrator; never set via SCIM or OIDC claims.
      t.boolean  :break_glass_admin,     null: false, default: false

      # externally_managed: true means lifecycle is owned by SCIM/OIDC.
      # Local users remain false; converting requires explicit admin action.
      t.boolean  :externally_managed,    null: false, default: false

      # provisioning_source: tracks how the account was created.
      # Values: "local", "oidc_jit", "scim", "scim_oidc"
      t.string   :provisioning_source,   default: "local"

      t.string   :display_name
      t.string   :avatar_url
      t.datetime :last_identity_sync_at
      t.datetime :disabled_at
      t.text     :identity_metadata  # JSON, serialized in model
    end

    add_index :users, :break_glass_admin
    add_index :users, :externally_managed
    add_index :users, :provisioning_source
  end
end
