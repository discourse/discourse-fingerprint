# frozen_string_literal: true

# name: discourse-fingerprint
# about: Computes user fingerprints to help administrators combat internet trolls.
# version: 1.0
# authors: Dan Ungureanu
# url: https://github.com/udan11/discourse-fingerprint.git

enabled_site_setting :fingerprint_enabled

add_admin_route 'fingerprint.title', 'fingerprint'

register_asset 'stylesheets/common/fingerprint.scss'
%w[desktop info mobile].each { |i| register_svg_icon(i) }

after_initialize do
  module ::DiscourseFingerprint
    PLUGIN_NAME         = 'discourse-fingerprint'
    IGNORE_CUSTOM_FIELD = 'fingerprint_ignore_user_ids'

    def self.get_hidden
      get_flagged('hide')
    end

    def self.get_silenced
      get_flagged('silence')
    end

    def self.get_flagged(type)
      if flagged = PluginStore.get(PLUGIN_NAME, "flagged_#{type}").presence
        flagged = flagged.split(',')
        flagged.uniq!
      else
        flagged = []
      end

      flagged
    end

    def self.flag(type, value, add: true)
      flagged = get_flagged(type)

      if add && !flagged.include?(value)
        flagged << value
      elsif !add && flagged.include?(value)
        flagged.delete(value)
      else
        return false
      end

      PluginStore.set(PLUGIN_NAME, "flagged_#{type}", flagged.join(','))
    end

    def self.get_ignores(user)
      if ignores = user.custom_fields[IGNORE_CUSTOM_FIELD].presence
        ignores = ignores.split(',').map(&:to_i)
        ignores << user.id
        ignores.uniq!
      else
        ignores = [user.id]
      end

      ignores
    end

    def self.ignore(user, other, add: true)
      ignores = get_ignores(user)
      if add && !ignores.include?(other.id)
        ignores << other.id
      elsif !add && ignores.include?(other.id)
        ignores.delete(other.id)
      else
        return false
      end

      user.custom_fields[IGNORE_CUSTOM_FIELD] = ignores.join(',')
      user.save_custom_fields
    end
  end

  load File.expand_path('../app/controllers/admin/fingerprint_controller.rb', __FILE__)
  load File.expand_path('../app/controllers/fingerprint_controller.rb', __FILE__)
  load File.expand_path('../app/models/fingerprint.rb', __FILE__)
  load File.expand_path('../app/serializers/fingerprint_serializer.rb', __FILE__)
  load File.expand_path('../app/serializers/fingerprint_users_serializer.rb', __FILE__)

  class DiscourseFingerprint::Engine < Rails::Engine
    engine_name DiscourseFingerprint::PLUGIN_NAME
    isolate_namespace DiscourseFingerprint
  end

  DiscourseFingerprint::Engine.routes.draw do
    post '/fingerprint'                           => 'fingerprint#index'

    get  '/admin/plugins/fingerprint'             => 'fingerprint_admin#index'
    get  '/admin/plugins/fingerprint/user_report' => 'fingerprint_admin#user_report'
    put  '/admin/plugins/fingerprint/flag'        => 'fingerprint_admin#flag'
    post '/admin/plugins/fingerprint/ignore'      => 'fingerprint_admin#ignore'
  end

  Discourse::Application.routes.append do
    mount ::DiscourseFingerprint::Engine, at: '/'
  end
end
