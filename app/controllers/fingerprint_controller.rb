# frozen_string_literal: true

class DiscourseFingerprint::FingerprintController < ApplicationController
  requires_plugin DiscourseFingerprint::PLUGIN_NAME

  before_action :ensure_logged_in
  skip_before_action :check_xhr

  FINGERPRINTED_HEADERS = ['Accept', 'Accept-Charset', 'Accept-Datetime', 'Accept-Encoding', 'Accept-Language', 'User-Agent']

  COOKIE_METHOD_NAME = 'cookie'
  SCRIPT_METHOD_NAME = 'fingerprintjs2'

  def index
    hash = cookies[:fp]
    cookies.permanent[:fp] = hash = SecureRandom.hex if hash.blank?
    Fingerprint.create_or_touch!(user: current_user, name: COOKIE_METHOD_NAME, value: hash)

    begin
      data = JSON.parse(params.require(:data))
    rescue JSON::ParserError
      raise Discourse::InvalidParameters(:data)
    end

    silenced = DiscourseFingerprint::get_silenced
    silence_user = false

    hash = request.remote_ip.to_s
    silence_user ||= silenced.include?(hash)
    Fingerprint.create_or_touch!(user: current_user, name: 'IP', value: hash, data: {})

    hash = Digest::SHA1::hexdigest(data.values.map(&:to_s).sort.to_s)
    silence_user ||= silenced.include?(hash)
    Fingerprint.create_or_touch!(user: current_user, name: SCRIPT_METHOD_NAME, value: hash, data: JSON.dump(data))

    # Compute hash without audio & canvas fingerprint info.
    # There are browser extensions that can block these fingerprinting methods.
    data = data.reject! { |k, _| k == 'audio' || k == 'canvas' }
    hash = Digest::SHA1::hexdigest(data.values.map(&:to_s).sort.to_s)
    silence_user ||= silenced.include?(hash)
    Fingerprint.create_or_touch!(user: current_user, name: "#{SCRIPT_METHOD_NAME}-audio-canvas", value: hash, data: JSON.dump(data))

    # Add request headers to fingerprint data for a better accuracy.
    FINGERPRINTED_HEADERS.each { |h| data[h] = request.headers[h] }
    hash = Digest::SHA1::hexdigest(data.values.map(&:to_s).sort.to_s)
    silence_user ||= silenced.include?(hash)
    Fingerprint.create_or_touch!(user: current_user, name: "#{SCRIPT_METHOD_NAME}+headers", value: hash, data: JSON.dump(data))

    if silence_user
      UserSilencer.new(
        current_user,
        Discourse.system_user,
        silenced_till: 1000.years.from_now,
        reason: I18n.t('fingerprint.silenced'),
        keep_posts: true
      )
    end

    render json: success_json
  end
end
