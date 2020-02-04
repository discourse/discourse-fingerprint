# frozen_string_literal: true

class CreateFingerprintTables < ActiveRecord::Migration[5.2]
  def change
    create_table :fingerprints do |t|
      t.integer :user_id, null: false
      t.string :name, null: false
      t.string :value, null: false
      t.text :data
      t.timestamps

      t.index :user_id
      t.index :value
    end

    create_table :flagged_fingerprints do |t|
      t.string :value, null: false
      t.boolean :hidden, null: false, default: false
      t.boolean :silenced, null: false, default: false
      t.timestamps

      t.index :value
      t.index :hidden
      t.index :silenced
    end

    # Migrate data from custom fields
    PluginStoreRow
      .where(plugin_name: 'discourse-fingerprint')
      .where('key LIKE \'user_%\'')
      .find_each do |row|

      user_id = row.key['user_'.length..row.key.length].to_i
      JSON.parse(row.value).each do |fingerprint_json|
        Fingerprint.create_or_touch!(
            user_id: user_id,
            name: fingerprint_json['type'],
            value: fingerprint_json['hash'],
            data: fingerprint_json['data'],
            created_at: fingerprint_json['first_time'],
            updated_at: fingerprint_json['last_time']
        )
      end
    end

    PluginStoreRow
      .where(plugin_name: 'discourse-fingerprint')
      .delete_all
  end
end
