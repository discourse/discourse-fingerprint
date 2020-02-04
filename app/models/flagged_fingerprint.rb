# frozen_string_literal: true

class FlaggedFingerprint < ActiveRecord::Base
end

# == Schema Information
#
# Table name: flagged_fingerprints
#
#  id         :bigint           not null, primary key
#  value      :string           not null
#  hidden     :boolean          default(FALSE), not null
#  silenced   :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_flagged_fingerprints_on_hidden    (hidden)
#  index_flagged_fingerprints_on_silenced  (silenced)
#  index_flagged_fingerprints_on_value     (value)
#
