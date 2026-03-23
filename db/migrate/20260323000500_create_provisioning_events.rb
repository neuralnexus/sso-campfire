class CreateProvisioningEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :provisioning_events do |t|
      t.references :identity_provider, null: false, foreign_key: true
      t.references :user,              foreign_key: true  # nullable: event may precede user creation
      t.string  :event_type,           null: false
      # event_type values: oidc_login, scim_create, scim_patch, scim_deactivate,
      #                    scim_reactivate, relink_denied, jit_provision, token_rotate
      t.string  :request_id
      t.string  :source_ip
      t.string  :user_agent
      t.integer :status_code
      t.boolean :success,              null: false, default: false
      t.string  :external_subject
      t.string  :scim_resource_id
      t.text    :details  # JSON, serialized in model
      t.timestamps
    end

    add_index :provisioning_events, [ :identity_provider_id, :created_at ]
    add_index :provisioning_events, :request_id
    add_index :provisioning_events, [ :user_id, :created_at ]
  end
end
