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
  end
end
