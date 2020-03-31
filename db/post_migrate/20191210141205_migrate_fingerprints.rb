# frozen_string_literal: true

class MigrateFingerprints < ActiveRecord::Migration[5.2]
  def change
    PluginStoreRow
      .where(plugin_name: 'discourse-fingerprint')
      .where('key LIKE \'user_%\'')
      .find_each do |row|

      user_id = row.key['user_'.length..row.key.length].to_i
      JSON.parse(row.value).each do |fingerprint|
        name = fingerprint['type']
        name = 'fingerprintjs2-' if name == 'fingerprintjs2-simple'
        data = fingerprint['data']
        Fingerprint.create_or_touch!(
          user_id: user_id,
          name: name,
          value: Fingerprint.compute_hash(data),
          data: JSON.dump(data),
          created_at: fingerprint['first_time'],
          updated_at: fingerprint['last_time']
        )
      end
    end

    PluginStoreRow
      .where(plugin_name: 'discourse-fingerprint')
      .delete_all
  end
end
