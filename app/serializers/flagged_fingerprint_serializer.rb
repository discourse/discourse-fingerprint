# frozen_string_literal: true

class FlaggedFingerprintSerializer < ApplicationSerializer
  attributes :name,
             :value,
             :hidden,
             :silenced,
             :data,
             :count,
             :is_common

  def include_name?
    scope.present? &&
    scope[:fingerprints].present? &&
    scope[:fingerprints][value].present?
  end

  def name
    scope[:fingerprints][value].name
  end

  def include_data?
    scope.present? &&
    scope[:fingerprints].present? &&
    scope[:fingerprints][value].present?
  end

  def data
    begin
      if scope[:fingerprints][value].data
        data = JSON.parse(scope[:fingerprints][value].data)
        return data if data.is_a?(Hash) && data.keys.length > 0
      end
    rescue JSON::ParserError
    end

    nil
  end

  def include_count?
    scope.present? &&
    scope[:fingerprints].present? &&
    scope[:fingerprints][value].present?
  end

  def count
    scope[:fingerprints][value].count
  end

  def include_is_common?
    include_data?
  end

  def is_common
    Fingerprint.is_common(data)
  end
end
