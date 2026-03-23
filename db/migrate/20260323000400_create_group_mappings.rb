class CreateGroupMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :group_mappings do |t|
      t.references :identity_provider, null: false, foreign_key: true
      t.string  :external_group_id
      t.string  :external_group_name
      t.string  :role    # "member" or "administrator"
      t.integer :room_id
      t.boolean :enabled,  null: false, default: true
      t.integer :priority, null: false, default: 100
      t.timestamps
    end

    add_foreign_key :group_mappings, :rooms, column: :room_id

    # Group claims only act when an explicit mapping exists — no implicit name matching
    add_index :group_mappings,
      [ :identity_provider_id, :external_group_id ],
      unique: true,
      where: "external_group_id IS NOT NULL",
      name: "idx_group_mappings_provider_group_id"
  end
end
