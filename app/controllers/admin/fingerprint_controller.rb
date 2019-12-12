# frozen_string_literal: true

class DiscourseFingerprint::FingerprintAdminController < Admin::AdminController
  requires_plugin DiscourseFingerprint::PLUGIN_NAME

  def index
    matches = Fingerprint
      .matches
      .where.not(value: DiscourseFingerprint::get_hidden)
      .order('MAX(updated_at) DESC')
      .limit(100)

    users = User
      .where(id: matches.map(&:user_ids).flatten.uniq)
      .to_h { |u| [u.id, u] }

    hidden = Set.new(DiscourseFingerprint::get_hidden)
    silenced = Set.new(DiscourseFingerprint::get_silenced)
    flagged = hidden + silenced
    counts = Fingerprint
      .select(:value, 'COUNT(*) count')
      .where(value: flagged)
      .group(:value)
      .to_h { |fp| [fp.value, fp.count] }

    flagged = flagged.to_a.map do |fp|
      {
        value: fp,
        count: counts[fp] || 0,
        hidden: hidden.include?(fp),
        silenced: silenced.include?(fp)
      }
    end

    render json: {
      matches: serialize_data(matches, FingerprintUsersSerializer, scope: { users: users }),
      flagged: flagged
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

    hidden_values = DiscourseFingerprint::get_hidden
    ignored_ids = DiscourseFingerprint::get_ignores(user)

    fingerprints = Fingerprint
      .where(user: user)
      .where.not(value: hidden_values)

    matches = Fingerprint.matches
      .where(value: fingerprints.pluck(:value))
      .to_h { |match| [match.value, match.user_ids - ignored_ids] }

    users = User
      .where(id: matches.values.flatten.uniq)
      .to_h { |u| [u.id, u] }

    render json: {
      user: BasicUserSerializer.new(user, root: false),
      fingerprints: serialize_data(fingerprints, FingerprintSerializer, scope: { matches: matches, users: users }),
      ignores: User.where(id: ignored_ids - [user.id]).map { |u| BasicUserSerializer.new(u, root: false) }
    }
  end

  # Hides a match from the 'Latest matches' page.
  #
  # Params:
  # +type+::    Type of flag
  # +value+::   Value of the fingerprint match to hide
  def flag
    raise Discourse::InvalidParameters(:value) if params[:value].blank?
    raise Discourse::InvalidParameters(:type) if params[:type] != 'hide' && params[:type] != 'silence'

    DiscourseFingerprint::flag(params[:type], params[:value], add: params[:remove].blank?)

    render json: success_json
  end

  # Adds a new pair of ignored users.
  #
  # Params:
  # +username+::        Name of the first user of the pair
  # +other_username+::  Name of the second user of the pair
  def ignore
    users = User.where(username: [params[:username], params[:other_username]])
    raise Discourse::InvalidParameters if users.size != 2

    DiscourseFingerprint::ignore(users[0], users[1])
    DiscourseFingerprint::ignore(users[1], users[0])

    render json: success_json
  end
end
