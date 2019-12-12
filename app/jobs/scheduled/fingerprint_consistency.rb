# frozen_string_literal: true

module Jobs
  class FingerprintConsistency < ::Jobs::Scheduled
    every 1.day

    def execute(args)
      Fingerprint.where('created_at < ?', 6.months.ago).delete_all

      Fingerprint
        .joins("LEFT JOIN users ON fingerprints.user_id = users.id")
        .where(users: { id: nil })
        .delete_all
    end
  end
end
