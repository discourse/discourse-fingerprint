# frozen_string_literal: true

class FingerprintUsersSerializer < ApplicationSerializer
  attributes :name,
             :value,
             :users

  def users
    object.user_ids.map! { |id| BasicUserSerializer.new(scope[:users][id], root: false) }
  end
end
