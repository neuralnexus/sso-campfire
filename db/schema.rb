# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.2].define(version: 2026_03_23_000600) do
  create_table "accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "custom_styles"
    t.string "join_code", null: false
    t.string "name", null: false
    t.json "settings"
    t.integer "singleton_guard", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["singleton_guard"], name: "index_accounts_on_singleton_guard", unique: true
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["ip_address"], name: "index_bans_on_ip_address"
    t.index ["user_id"], name: "index_bans_on_user_id"
  end

  create_table "boosts", force: :cascade do |t|
    t.integer "booster_id", null: false
    t.string "content", limit: 16, null: false
    t.datetime "created_at", null: false
    t.integer "message_id", null: false
    t.datetime "updated_at", null: false
    t.index ["booster_id"], name: "index_boosts_on_booster_id"
    t.index ["message_id"], name: "index_boosts_on_message_id"
  end

  create_table "external_identities", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "deprovisioned_at"
    t.string "email_at_link_time"
    t.boolean "externally_managed", default: true, null: false
    t.integer "identity_provider_id", null: false
    t.datetime "last_authenticated_at"
    t.text "last_claims"
    t.datetime "last_scim_sync_at"
    t.text "metadata"
    t.string "provider_subject", null: false
    t.string "scim_external_id"
    t.string "scim_resource_id"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "username_at_link_time"
    t.index ["identity_provider_id", "provider_subject"], name: "idx_external_identities_provider_subject", unique: true
    t.index ["identity_provider_id", "scim_external_id"], name: "idx_external_identities_provider_scim_external_id", unique: true, where: "scim_external_id IS NOT NULL"
    t.index ["identity_provider_id", "scim_resource_id"], name: "idx_external_identities_provider_scim_resource_id", unique: true, where: "scim_resource_id IS NOT NULL"
    t.index ["identity_provider_id"], name: "index_external_identities_on_identity_provider_id"
    t.index ["user_id"], name: "index_external_identities_on_user_id"
  end

  create_table "group_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.string "external_group_id"
    t.string "external_group_name"
    t.integer "identity_provider_id", null: false
    t.integer "priority", default: 100, null: false
    t.string "role"
    t.integer "room_id"
    t.datetime "updated_at", null: false
    t.index ["identity_provider_id", "external_group_id"], name: "idx_group_mappings_provider_group_id", unique: true, where: "external_group_id IS NOT NULL"
    t.index ["identity_provider_id"], name: "index_group_mappings_on_identity_provider_id"
  end

  create_table "identity_providers", force: :cascade do |t|
    t.boolean "allow_email_linking", default: false, null: false
    t.string "authorization_endpoint"
    t.string "claim_email", default: "email", null: false
    t.string "claim_email_verified", default: "email_verified", null: false
    t.string "claim_groups", default: "groups", null: false
    t.string "claim_name", default: "name", null: false
    t.string "claim_sub", default: "sub", null: false
    t.string "client_id", null: false
    t.integer "clock_skew_seconds", default: 60, null: false
    t.datetime "created_at", null: false
    t.string "discovery_url", null: false
    t.boolean "enabled", default: false, null: false
    t.text "encrypted_client_secret", null: false
    t.string "encrypted_client_secret_iv", null: false
    t.string "end_session_endpoint"
    t.string "issuer", null: false
    t.boolean "jit_provisioning", default: true, null: false
    t.string "jwks_uri"
    t.datetime "last_metadata_refresh_at"
    t.string "name", null: false
    t.string "protocol", null: false
    t.boolean "require_email_verified", default: true, null: false
    t.boolean "require_pkce", default: true, null: false
    t.boolean "scim_enabled", default: false, null: false
    t.string "scopes", default: "openid email profile", null: false
    t.text "settings"
    t.boolean "soft_delete_on_scim_deactivate", default: true, null: false
    t.string "token_endpoint"
    t.datetime "updated_at", null: false
    t.string "userinfo_endpoint"
    t.index ["enabled"], name: "index_identity_providers_on_enabled"
    t.index ["issuer"], name: "index_identity_providers_on_issuer", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.datetime "connected_at"
    t.integer "connections", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "involvement", default: "mentions"
    t.integer "room_id", null: false
    t.datetime "unread_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["room_id", "created_at"], name: "index_memberships_on_room_id_and_created_at"
    t.index ["room_id", "user_id"], name: "index_memberships_on_room_id_and_user_id", unique: true
    t.index ["room_id"], name: "index_memberships_on_room_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.string "client_message_id", null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.integer "room_id", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_messages_on_creator_id"
    t.index ["room_id"], name: "index_messages_on_room_id"
  end

  create_table "provisioning_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "details"
    t.string "event_type", null: false
    t.string "external_subject"
    t.integer "identity_provider_id", null: false
    t.string "request_id"
    t.string "scim_resource_id"
    t.string "source_ip"
    t.integer "status_code"
    t.boolean "success", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id"
    t.index ["identity_provider_id", "created_at"], name: "idx_on_identity_provider_id_created_at_3434f0d617"
    t.index ["identity_provider_id"], name: "index_provisioning_events_on_identity_provider_id"
    t.index ["request_id"], name: "index_provisioning_events_on_request_id"
    t.index ["user_id", "created_at"], name: "index_provisioning_events_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_provisioning_events_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.string "auth_key"
    t.datetime "created_at", null: false
    t.string "endpoint"
    t.string "p256dh_key"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["endpoint", "p256dh_key", "auth_key"], name: "idx_on_endpoint_p256dh_key_auth_key_7553014576"
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.string "name"
    t.string "type", null: false
    t.datetime "updated_at", null: false
  end

  create_table "scim_tokens", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.integer "identity_provider_id", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.text "scopes"
    t.string "token_fingerprint", null: false
    t.datetime "updated_at", null: false
    t.index ["identity_provider_id", "active"], name: "index_scim_tokens_on_identity_provider_id_and_active"
    t.index ["identity_provider_id"], name: "index_scim_tokens_on_identity_provider_id"
    t.index ["token_fingerprint"], name: "index_scim_tokens_on_token_fingerprint", unique: true
  end

  create_table "searches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "query", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_searches_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.text "bio"
    t.string "bot_token"
    t.boolean "break_glass_admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "disabled_at"
    t.string "display_name"
    t.string "email_address"
    t.boolean "externally_managed", default: false, null: false
    t.text "identity_metadata"
    t.datetime "last_identity_sync_at"
    t.string "name", null: false
    t.string "password_digest"
    t.string "provisioning_source", default: "local"
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["bot_token"], name: "index_users_on_bot_token", unique: true
    t.index ["break_glass_admin"], name: "index_users_on_break_glass_admin"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["externally_managed"], name: "index_users_on_externally_managed"
    t.index ["provisioning_source"], name: "index_users_on_provisioning_source"
  end

  create_table "webhooks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_webhooks_on_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bans", "users"
  add_foreign_key "boosts", "messages"
  add_foreign_key "external_identities", "identity_providers"
  add_foreign_key "external_identities", "users"
  add_foreign_key "group_mappings", "identity_providers"
  add_foreign_key "group_mappings", "rooms"
  add_foreign_key "messages", "rooms"
  add_foreign_key "messages", "users", column: "creator_id"
  add_foreign_key "provisioning_events", "identity_providers"
  add_foreign_key "provisioning_events", "users"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "scim_tokens", "identity_providers"
  add_foreign_key "searches", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "webhooks", "users"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "message_search_index", "fts5", ["body", "tokenize=porter"]
end
