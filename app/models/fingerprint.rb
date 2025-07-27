# frozen_string_literal: true

class Fingerprint < ActiveRecord::Base
  belongs_to :user

  # Selects fingerprints that are shared by more than one user.
  # Groups by the fingerprint hash ('value') for efficiency, as it's the canonical representation.
  def self.matches
    select(:name, :value, "MAX(data) AS data", "ARRAY_AGG(user_id ORDER BY user_id) AS user_ids")
      .group(:name, :value)
      .having("COUNT(user_id) > 1")
  end

  # Finds an existing fingerprint for the user or creates a new one.
  # If found, it updates the `updated_at` timestamp to mark recent activity.
  def self.find_or_create_with_touch!(attributes)
    # Ensure we are looking up with the correct, indexed attributes.
    lookup_attrs = { user_id: attributes[:user_id], value: attributes[:value] }

    if (fingerprint = find_by(lookup_attrs))
      fingerprint.touch
      fingerprint
    else
      create!(attributes)
    end
  end

  # Computes a secure and consistent hash from the fingerprint data.
  # Uses SHA256, a more modern and secure hashing algorithm than SHA1.
  def self.compute_hash(data)
    # Sorting values ensures the hash is consistent regardless of key order.
    canonical_string = data.values.map(&:to_s).sort.join
    Digest::SHA256.hexdigest(canonical_string)
  end

  # A simple check to identify fingerprints from common mobile Apple devices.
  # These are often too generic to be useful for identifying unique users.
  def self.is_common?(data)
    return false if data.blank?

    platform = data["navigator_platform"].to_s
    user_agent = (data["User-Agent"] || data["user_agent"]).to_s

    # Regex checks for common iOS/iPadOS devices and generic Safari UAs.
    !!(
      platform.match?(/iPad|iPhone|iPod/) ||
      user_agent.match?(%r{Version/(\d+).+?Safari}) ||
      user_agent.match?(/iPad|iPhone|iPod/)
    )
  end
end

# == Schema Information
#
# Table name: fingerprints
#
#  id         :bigint           not null, primary key
#  user_id    :integer          not null
#  name       :string           not null
#  value      :string           not null
#  data       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_fingerprints_on_user_id  (user_id)
#  index_fingerprints_on_value    (value)
#
