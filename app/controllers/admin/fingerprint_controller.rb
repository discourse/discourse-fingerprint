# frozen_string_literal: true

class DiscourseFingerprint::FingerprintAdminController < Admin::AdminController
  requires_plugin DiscourseFingerprint::PLUGIN_NAME

  def index
    matches = Fingerprint
      .matches
      .where.not(value: FlaggedFingerprint.select(:value))
      .order('MAX(updated_at) DESC')
      .limit(20)

    flagged = FlaggedFingerprint.all

    flagged_fingerprints = Fingerprint
      .select(:name, :value, :data, 'COUNT(*) count')
      .where(value: FlaggedFingerprint.select(:value))
      .group(:name, :value, :data)
      .to_h { |fp| [fp.value, fp] }

    users = User.where(id: matches.map(&:user_ids).flatten.uniq)

    render json: {
      fingerprints: serialize_data(matches, FingerprintSerializer, scope: { flagged: flagged.to_h { |fp| [fp.value, fp] } }),
      flagged: serialize_data(flagged, FlaggedFingerprintSerializer, scope: { fingerprints: flagged_fingerprints }),
      users: users.map { |u| [u.id, BasicUserSerializer.new(u, root: false)] }.to_h
    }
  end

  # Generates a user report.
  #
  # Params:
  # +username+::  Name of the user for which the request has been made
  #
  # Returns a hash containing all user fingerprints and a list of
  # matching users having similar fingerprints.
  def user_report
    user = User.find_by_username(params[:username])
    raise Discourse::InvalidParameters.new(:username) if !user

    ignored_ids = DiscourseFingerprint::get_ignores(user)

    fingerprints = Fingerprint
      .where(user: user)
      .where.not(value: FlaggedFingerprint.select(:value).where(hidden: true))

    user_ids = Fingerprint
      .matches
      .where(value: fingerprints.pluck(:value))
      .to_h { |match| [match.value, match.user_ids - [user.id]] }

    users = User.where(id: user_ids.values.flatten.uniq).or(User.where(id: ignored_ids))

    render json: {
      user: BasicUserSerializer.new(user, root: false),
      ignored_ids: ignored_ids,
      fingerprints: serialize_data(fingerprints, FingerprintSerializer, scope: { user_ids: user_ids }),
      users: users.map { |u| [u.id, BasicUserSerializer.new(u, root: false)] }.to_h,
    }
  end

  # Hides a match from the 'Latest matches' page.
  #
  # Params:
  # +type+::    Type of flag (hide or silence)
  # +value+::   Value of the fingerprint match to hide
  # +remove+::  Whether this operation is adding or removing the flag
  def flag
    raise Discourse::InvalidParameters.new(:value) if params[:value].blank?
    raise Discourse::InvalidParameters.new(:type)  if params[:type] != 'hide' && params[:type] != 'silence'

    flagged = FlaggedFingerprint.find_by(value: params[:value]) ||
              FlaggedFingerprint.new(value: params[:value])

    if params[:type] == 'hide'
      flagged.hidden = params[:remove].blank?
    elsif params[:type] == 'silence'
      flagged.silenced = params[:remove].blank?
    end

    if flagged.hidden || flagged.silenced
      flagged.save
    else
      flagged.delete
    end

    render json: success_json
  end

  # Adds a new pair of ignored users.
  #
  # Params:
  # +username+::        Name of the first user of the pair
  # +other_username+::  Name of the second user of the pair
  # +remove+::          Whether this operation is adding or removing the ignore
  def ignore
    users = User.where(username: [params[:username], params[:other_username]])
    raise Discourse::InvalidParameters.new if users.size != 2

    DiscourseFingerprint::ignore(users[0], users[1], add: params[:remove].blank?)
    DiscourseFingerprint::ignore(users[1], users[0], add: params[:remove].blank?)

    render json: success_json
  end
end
