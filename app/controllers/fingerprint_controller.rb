# frozen_string_literal: true

class DiscourseFingerprint::FingerprintController < ApplicationController
  requires_plugin DiscourseFingerprint::PLUGIN_NAME

  before_action :ensure_logged_in
  skip_before_action :check_xhr

  FINGERPRINTED_HEADERS = ['Accept', 'Accept-Charset', 'Accept-Datetime', 'Accept-Encoding', 'Accept-Language', 'User-Agent']

  COOKIE_METHOD_NAME = 'cookie'
  IP_METHOD_NAME = 'ip'
  SCRIPT_METHOD_NAME = 'fingerprintjs2'

  def index
    hashes = []

    if SiteSetting.fingerprint_cookie?
      hash = cookies[:fp]
      cookies.permanent[:fp] = hash = SecureRandom.hex if hash.blank?
      hashes << hash
      Fingerprint.create_or_touch!(user: current_user, name: COOKIE_METHOD_NAME, value: hash)
    end

    if SiteSetting.fingerprint_ip?
      hashes << (hash = request.remote_ip.to_s)
      info = DiscourseIpInfo.get(request.remote_ip)
      Fingerprint.create_or_touch!(user: current_user, name: IP_METHOD_NAME, value: hash, data: info.presence && JSON.dump(info))
    end

    visitor_id = params.require(:visitor_id)
    version = params.require(:version)
    data = params.require(:data)

    if visitor_id.present? && version.present? && data.present?
      hashes << (hash = visitor_id)
      Fingerprint.create_or_touch!(user: current_user, name: SCRIPT_METHOD_NAME, value: hash, data: data)

      # Build an additional fingerprint with original hash and browser headers
      data = { visitor_id: visitor_id, version: params.require(:version) }
      FINGERPRINTED_HEADERS.each { |h| data[h] = request.headers[h] if request.headers[h].present? }

      hashes << (hash = Fingerprint.compute_hash(data))
      Fingerprint.create_or_touch!(user: current_user, name: "#{SCRIPT_METHOD_NAME}+", value: hash, data: JSON.dump(data))
    end

    if !current_user.silenced? && FlaggedFingerprint.find_by(value: hashes, silenced: true).present?
      UserSilencer.new(
        current_user,
        Discourse.system_user,
        silenced_till: 1000.years.from_now,
        reason: I18n.t('fingerprint.silenced'),
        keep_posts: true
      ).silence
    end

    render json: success_json
  end
end
