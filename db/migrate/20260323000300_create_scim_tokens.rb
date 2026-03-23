class CreateScimTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :scim_tokens do |t|
      t.references :identity_provider, null: false, foreign_key: true
      t.string  :token_fingerprint,    null: false
      t.string  :name,                 null: false
      t.boolean :active,               null: false, default: true
      t.datetime :last_used_at
      t.datetime :expires_at
      t.text    :scopes  # JSON array, serialized in model; default ["scim:read","scim:write"]
      t.timestamps
    end

    # Fingerprint is the HMAC-SHA256 of the raw bearer token — never store plaintext
    add_index :scim_tokens, :token_fingerprint, unique: true
    add_index :scim_tokens, [ :identity_provider_id, :active ]
  end
end
