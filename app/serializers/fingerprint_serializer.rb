# frozen_string_literal: true

class FingerprintSerializer < ApplicationSerializer
  attributes :name,
             :value,
             :data,
             :device_type,
             :is_common,
             :created_at,
             :updated_at,
             :user_ids,
             :hidden,
             :silenced

  def include_data?
    data.present?
  end

  def data
    if object.data
      data = JSON.parse(object.data)
      return data if data.is_a?(Hash) && data.keys.length > 0
    end
  rescue JSON::ParserError
  end

  def include_device_type?
    include_data?
  end

  def device_type
    user_agent = data['User-Agent'] || data['user_agent']
    MobileDetection.mobile_device?(user_agent) ? 'mobile' : 'desktop'
  end

  def include_is_common?
    include_data?
  end

  def is_common
    Fingerprint.is_common(data)
  end

  def include_created_at?
    object.has_attribute?(:created_at)
  end

  def include_updated_at?
    object.has_attribute?(:updated_at)
  end

  def include_user_ids?
    !!user_ids
  end

  def user_ids
    if object.has_attribute?(:user_ids)
      object.user_ids || []
    elsif scope.present? && scope[:user_ids].present?
      scope[:user_ids][object.value] || []
    end
  end

  def include_hidden?
    scope.present? && scope[:flagged].present?
  end

  def hidden
    scope[:flagged][object.value]&.hidden
  end

  def include_silenced?
    scope.present? && scope[:flagged].present?
  end

  def silenced
    scope[:flagged][object.value]&.silenced
  end
end
