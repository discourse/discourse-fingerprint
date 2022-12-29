# frozen_string_literal: true

# name: discourse-fingerprint
# about: Computes user fingerprints to help administrators combat internet trolls.
# version: 2.0
# authors: Dan Ungureanu
# url: https://github.com/udan11/discourse-fingerprint.git
# transpile_js: true

enabled_site_setting :fingerprint_enabled

add_admin_route "fingerprint.title", "fingerprint"

register_asset "stylesheets/common/fingerprint.scss"
%w[
  desktop
  far-eye
  far-eye-slash
  info
  layer-group
  microphone
  microphone-slash
  mobile
  user
  user-slash
].each { |i| register_svg_icon(i) }

after_initialize do
  module ::DiscourseFingerprint
    PLUGIN_NAME = "discourse-fingerprint"
    IGNORE_CUSTOM_FIELD = "fingerprint_ignore_user_ids"

    def self.get_ignores(user)
      if ignores = user.custom_fields[IGNORE_CUSTOM_FIELD].presence
        ignores.split(",").map(&:to_i).uniq
      else
        []
      end
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

      user.custom_fields[IGNORE_CUSTOM_FIELD] = ignores.join(",")
      user.save_custom_fields
    end
  end

  load File.expand_path("../app/controllers/admin/fingerprint_controller.rb", __FILE__)
  load File.expand_path("../app/controllers/fingerprint_controller.rb", __FILE__)
  load File.expand_path("../app/jobs/scheduled/fingerprint_consistency.rb", __FILE__)
  load File.expand_path("../app/models/fingerprint.rb", __FILE__)
  load File.expand_path("../app/models/flagged_fingerprint.rb", __FILE__)
  load File.expand_path("../app/serializers/fingerprint_serializer.rb", __FILE__)
  load File.expand_path("../app/serializers/flagged_fingerprint_serializer.rb", __FILE__)

  class DiscourseFingerprint::Engine < Rails::Engine
    engine_name DiscourseFingerprint::PLUGIN_NAME
    isolate_namespace DiscourseFingerprint
  end

  DiscourseFingerprint::Engine.routes.draw do
    post "/fingerprint" => "fingerprint#index"

    get "/admin/plugins/fingerprint" => "fingerprint_admin#index"
    get "/admin/plugins/fingerprint/user_report" => "fingerprint_admin#user_report"
    put "/admin/plugins/fingerprint/flag" => "fingerprint_admin#flag"
    post "/admin/plugins/fingerprint/ignore" => "fingerprint_admin#ignore"
  end

  Discourse::Application.routes.append { mount ::DiscourseFingerprint::Engine, at: "/" }
end
