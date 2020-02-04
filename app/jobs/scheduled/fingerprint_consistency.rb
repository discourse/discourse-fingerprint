# frozen_string_literal: true

module Jobs
  class FingerprintConsistency < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      # Delete fingerprints of users that no longer exist
      Fingerprint
        .joins("LEFT JOIN users ON fingerprints.user_id = users.id")
        .where(users: { id: nil })
        .delete_all

      # Keep at most `max_fingerprints` fingerprints
      DB.exec(<<~SQL, max_fingerprints: SiteSetting.max_fingerprints)
        WITH ids_and_rownums as (
          SELECT id, user_id, updated_at, row_number()
          OVER (PARTITION BY user_id ORDER BY updated_at DESC) rownum
          FROM fingerprints
        )
          DELETE FROM fingerprints
          WHERE id IN (SELECT id FROM ids_and_rownums WHERE rownum >= :max_fingerprints)
      SQL

      # Delete stale custom fields
      PluginStoreRow
        .where(plugin_name: ::DiscourseFingerprint::PLUGIN_NAME)
        .where.not(key: ::DiscourseFingerprint::IGNORE_CUSTOM_FIELD)
        .delete_all
    end
  end
end
