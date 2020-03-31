# frozen_string_literal: true

class DiscourseFingerprint::FingerprintController < ApplicationController
  requires_plugin DiscourseFingerprint::PLUGIN_NAME

  before_action :ensure_logged_in
  skip_before_action :check_xhr

  FINGERPRINTED_HEADERS = ['Accept', 'Accept-Charset', 'Accept-Datetime', 'Accept-Encoding', 'Accept-Language', 'User-Agent']

  COOKIE_METHOD_NAME = 'cookie'
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
      Fingerprint.create_or_touch!(user: current_user, name: 'IP', value: hash, data: info.presence && JSON.dump(info))
    end

    begin
      data = JSON.parse(params.require(:data))
    rescue JSON::ParserError
    end

    if data
      hashes << (hash = Fingerprint.compute_hash(data))
      Fingerprint.create_or_touch!(user: current_user, name: SCRIPT_METHOD_NAME, value: hash, data: JSON.dump(data))

      # There are browser extensions that can block these fingerprinting
      # methods and produce weird fingerprints.
      data = data.reject! { |k, _| ["audio", "canvas", "fonts", "webgl"].include?(k) }
      hashes << (hash = Fingerprint.compute_hash(data))
      Fingerprint.create_or_touch!(user: current_user, name: "#{SCRIPT_METHOD_NAME}-", value: hash, data: JSON.dump(data))

      # Add request headers to fingerprint data for a better accuracy.
      FINGERPRINTED_HEADERS.each { |h| data[h] = request.headers[h] }
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
