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
  end
end
