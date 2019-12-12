# frozen_string_literal: true

module Jobs
  class MigrateFingerprintsToModels < ::Jobs::Onceoff
    def execute_onceoff(args)
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
end
