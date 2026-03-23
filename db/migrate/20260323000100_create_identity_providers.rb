class CreateIdentityProviders < ActiveRecord::Migration[8.2]
  def change
    create_table :identity_providers do |t|
      t.string  :name,                        null: false
      t.string  :protocol,                    null: false  # "oidc"
      t.string  :issuer,                      null: false
      t.string  :discovery_url,               null: false
      t.string  :client_id,                   null: false
      t.text    :encrypted_client_secret,     null: false
      t.string  :encrypted_client_secret_iv,  null: false
      t.string  :authorization_endpoint
      t.string  :token_endpoint
      t.string  :userinfo_endpoint
      t.string  :jwks_uri
      t.string  :end_session_endpoint
      t.string  :scopes,                      null: false, default: "openid email profile"
      t.string  :claim_sub,                   null: false, default: "sub"
      t.string  :claim_email,                 null: false, default: "email"
      t.string  :claim_email_verified,        null: false, default: "email_verified"
      t.string  :claim_name,                  null: false, default: "name"
      t.string  :claim_groups,                null: false, default: "groups"
      t.boolean :enabled,                     null: false, default: false
      t.boolean :jit_provisioning,            null: false, default: true
      t.boolean :scim_enabled,                null: false, default: false
      t.boolean :require_pkce,                null: false, default: true
      t.boolean :require_email_verified,      null: false, default: true
      t.boolean :allow_email_linking,         null: false, default: false
      t.boolean :soft_delete_on_scim_deactivate, null: false, default: true
      t.integer :clock_skew_seconds,          null: false, default: 60
      t.text    :settings  # JSON, serialized in model
      t.datetime :last_metadata_refresh_at
      t.timestamps
    end

    add_index :identity_providers, :issuer, unique: true
    add_index :identity_providers, :enabled
  end
end
