# frozen_string_literal: true

class FingerprintSerializer < ApplicationSerializer
  attributes :name,
             :value,
             :data,
             :device_type,
             :matches,
             :created_at,
             :updated_at

  def data
    JSON.parse(object.data) rescue {}
  end

  def device_type
    user_agent = data['User-Agent'] || data['user_agent']
    MobileDetection.mobile_device?(user_agent) ? 'mobile' : 'desktop'
  end

  def include_matches?
    scope.present?
  end

  def matches
    matches = scope[:matches][object.value] || []
    matches.map! { |id| BasicUserSerializer.new(scope[:users][id], root: false) }
  end
end
