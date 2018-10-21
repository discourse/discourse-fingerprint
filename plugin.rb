# name: discourse-fingerprint
# about: Computes user fingerprints to help administrators combat internet trolls.
# version: 1.0
# authors: Dan Ungureanu
# url: https://github.com/udan11/discourse-fingerprint.git

enabled_site_setting :fingerprint_enabled

add_admin_route 'fingerprint.title', 'fingerprint'

after_initialize do

  require_dependency 'admin/admin_controller'
  require_dependency 'application_controller'
  require_dependency 'plugin_store'
  require_dependency 'mobile_detection'

  module ::DiscourseFingerprint
    PLUGIN_NAME = 'discourse-fingerprint'
    FINGERPRINTED_HEADERS = ['Accept', 'Accept-Charset', 'Accept-Datetime', 'Accept-Encoding', 'Accept-Language', 'User-Agent']

    # Wrapper around +PluginStore+ that offers support for batch operations
    # such as +get_all+.
    class Store
      def self.set(key, value)
        ::PluginStore.set(PLUGIN_NAME, key, value)
      end

      def self.get(key)
        ::PluginStore.get(PLUGIN_NAME, key)
      end

      def self.remove(key)
        ::PluginStore.remove(PLUGIN_NAME, key)
      end

      # Gets all associated values to an array of keys.
      #
      # If the key does not exist or the associated value is +nil+ nothing will
      # be added to returned hash.
      #
      # Params:
      # +keys+::  Array of keys to be queried.
      #
      # Returns a hash of keys and associated values.
      def self.get_all(keys)
        rows = PluginStoreRow.where('plugin_name = ? AND key IN (?)', PLUGIN_NAME, keys).to_a

        Hash[rows.map { |row| [row.key, ::PluginStore.cast_value(row.type_name, row.value)] }]
      end
    end

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseFingerprint
    end

    # Manages user fingerprints and handles matches.
    #
    # Every fingerprint object is a hash having
    #   +:type+::         Name of the fingerprinting algorithm
    #   +:hash+::         Actual value of the fingerprint as returned by the
    #                     algorithm
    #   +:data+::         Miscellaneous data returned by the fingerprinting algorithm.
    #   +:first_time+::   First time the signature has been seen for the
    #                     current user
    #   +:last_time+::    Last time the signature has been seen for the current
    #                     user
    #
    # Matches are array containing user IDs that have the same fingerprint.
    # Two fingerprints are the same if they have the same type and same hash.
    #
    # To store fingerprints and matches, multiple +PluginStore+ keys are
    # used imitating a bidirectional map between users and fingerprints. The
    # following keys are used:
    #
    #   +user_%+::    Used to store arrays of fingerprint objects.
    #                 Key is parametrized by user ID.
    #
    #   +hash_%_%+::  Used to store matches for a specific fingerprint.
    #                 Key is parametrized by type and hash value.
    #
    #   +match+::  Used to store latest +hash_%_%+ keys that are associated
    #                 with matches involving more than 1 user.
    class Fingerprint

      # Adds a new fingerprint to +user_id+.
      #
      # This method may remove the oldest known fingerprint assigned to
      # +user_id+ if the ring buffer is full.
      #
      # By design, only the latest +SiteSetting.max_fingerprints+ are stored.
      #
      # Params:
      # +user_id+::   User to whom the new fingerprint belongs
      # +type+::      Signature's type (name of fingerprint algorithm)
      # +hash+::      Fingerprint value
      # +data+::      Miscellaneous data provided by the algorithm
      def self.add(user_id, type, hash, data)
        user_key = "user_#{user_id}"
        hash_key = "hash_#{type}_#{hash}"

        fingerprints = Store.get(user_key) || []

        # Looking to update an existent matching fingerprint.
        idx = fingerprints.find_index { |f| f[:type] == type && f[:hash] == hash }
        if idx
          fingerprints[idx][:data] = data
          fingerprints[idx][:last_time] = Time.zone.now.to_s
          Store.set(user_key, fingerprints)
          return nil
        end

        # Making space for the new fingerprint.
        if fingerprints.size >= SiteSetting.max_fingerprints
          fingerprints.sort! { |a, b| a[:last_time].to_time - b[:last_time].to_time }
          while fingerprints.size >= SiteSetting.max_fingerprints do
            remove(user_id, fingerprints.shift)
          end
        end

        # Assigning the new fingerprint to the user.
        fingerprints << {
          type:       type,
          hash:       hash,
          data:       data,
          first_time: Time.zone.now.to_s,
          last_time:  Time.zone.now.to_s,
        }
        Store.set(user_key, fingerprints)

        # Assigning the user to the new fingerprint.
        users = Store.get(hash_key) || []
        users << user_id
        Store.set(hash_key, users)

        # Checking user for matches.
        matches = get_matches
        matches_updated = false
        get_user_matches(user_id, fingerprints).each do |other_user_id|
          if !matches.include?([user_id, other_user_id]) && !matches.include?([other_user_id, user_id])
            matches << [other_user_id, user_id]
            matches_updated = true
          end
        end
        Store.set('matches', matches.last(SiteSetting.max_fingerprint_matches)) if matches_updated

        nil
      end

      # Removes a fingerprint from +user_id+.
      #
      # Params:
      # +user_id+::     User to whom the fingerprint belongs
      # +fingerprint+:: Fingerprint to be deleted
      def self.remove(user_id, fingerprint)
        user_key = "user_#{user_id}"
        hash_key = "hash_#{fingerprint[:type]}_#{fingerprint[:hash]}"

        # Removing fingerprint from user.
        fingerprints = Store.get(user_key) || []
        fingerprints.delete_if { |f| f[:type] == fingerprint[:type] && f[:hash] = fingerprint[:hash] }
        if fingerprints.size > 0
          Store.set(user_key, fingerprints)
        else
          Store.remove(user_key)
        end

        # Removing user from fingerprint.
        users = Store.get(hash_key) || []
        users.delete(user_id)
        if users.size > 0
          Store.set(hash_key, users)
        else
          Store.remove(hash_key)
        end

        nil
      end

      # Ignores all matches of +user_a+ with +user_b+.
      #
      # Params:
      # +user_a+::  First user of the pair
      # +user_b+::  Second user of the pair
      # +add+::     Whether this adds or removes an ignore entry
      def self.ignore(user_a, user_b, add = true)
        ignore_key_a = "ignore_#{user_a}"
        ignore_key_b = "ignore_#{user_b}"

        ignore_a = Store.get(ignore_key_a) || []
        ignore_b = Store.get(ignore_key_b) || []

        if add
          ignore_a << user_b unless ignore_a.include?(user_b)
          ignore_b << user_a unless ignore_b.include?(user_a)
        else
          ignore_a.delete(user_b)
          ignore_b.delete(user_a)
        end

        if ignore_a.size > 0
          Store.set(ignore_key_a, ignore_a)
        else
          Store.remove(ignore_key_a)
        end

        if ignore_b.size > 0
          Store.set(ignore_key_b, ignore_b)
        else
          Store.remove(ignore_key_b)
        end

        nil
      end

      # Gets all fingerprints of +user_id+.
      #
      # Each fingerprint object is augmented with an array of matches.
      #
      # Params:
      # +user_id+::     User to be queried
      #
      # Returns a list of all fingerprints.
      def self.get_fingerprints(user_id)
        user_key = "user_#{user_id}"
        ignore_key = "ignore_#{user_id}"

        fingerprints = Store.get(user_key) || []
        ignores = Store.get(ignore_key) || []
        ignores << user_id

        hash_keys = fingerprints.map { |f| "hash_#{f[:type]}_#{f[:hash]}" }
        other_user_ids = Store.get_all(hash_keys)
        fingerprints.each { |f|
          hash_key = "hash_#{f[:type]}_#{f[:hash]}"
          f[:matches] = (other_user_ids[hash_key] || []) - ignores
          if f[:data].key?('User-Agent') || f[:data].key?('user_agent')
            f[:device_type] = MobileDetection.mobile_device?(f[:data]['User-Agent'] || f[:data]['user_agent']) ? 'mobile' : 'desktop'
          elsif f[:data].key?('0')
            f[:device_type] = MobileDetection.mobile_device?(f[:data]['0']['value']) ? 'mobile' : 'desktop'
          end
        }

        fingerprints
      end

      # Gets latest matches.
      #
      # This method shall not return more than +SiteSettings.max_fingerprint_matches+.
      #
      # Returns a list of matches.
      def self.get_matches
        matches = Store.get('matches') || []

        # TODO: Remove this in the future. It is used to remove old matches
        # that would otherwise cause issues.
        matches.reject! { |x| x.instance_of? String }

        matches
      end

      # Computes matches for a specific user having a set of fingerprints.
      #
      # A match is generated if at least +SiteSetting.min_fingerprints_for_match+
      # are the same.
      #
      # Params:
      # +user_id+::       User's ID
      # +fingerprints+::  User's fingerprints
      #
      # Returns a list of matching user IDs.
      def self.get_user_matches(user_id, fingerprints)
        hash_keys = fingerprints.map { |f| "hash_#{f[:type]}_#{f[:hash]}" }
        other_user_ids = Store.get_all(hash_keys)

        # Hash storing number of matches between +user_id+ and each user of
        # +other_user_ids+.
        num_matches = Hash.new(0)
        other_user_ids.each { |key, value|
          value.each { |other_user_id| num_matches[other_user_id] += 1 }
        }

        # Returning only user IDs that match criteria.
        num_matches.select { |k, v| k != user_id && v >= SiteSetting.min_fingerprints_for_match }.keys
      end

    end

    # Controller used to record new user fingerprints.
    class FingerprintController < ::ApplicationController
      requires_plugin PLUGIN_NAME

      before_action :ensure_logged_in
      skip_before_action :check_xhr

      def index
        user_id = current_user.id
        type    = params.require(:type)
        hash    = params.fetch(:hash, nil)
        data    = params.fetch(:data, {})

        # Saving original hash value.
        data["#{type}_hash"] = hash

        # Adding request headers to fingerprint data for a better accuracy.
        # This requires recomputing the fingerprint hash.
        FINGERPRINTED_HEADERS.each { |h| data[h] = request.headers[h] }
        hash = Digest::SHA1::hexdigest(data.values.map(&:to_s).sort.to_s)
        Fingerprint.add(user_id, "#{type}+", hash, data)

        # Compute Fingerprintjs2 hash without audio & canvas fingerprinting.
        # There are browser extensions that can block these fingerprinting
        # methods.
        if type == 'fingerprintjs2'
          new_data = data.reject { |k, _| ["#{type}_hash", 'audio_fp', 'canvas'].include?(k) }
          new_hash = Digest::SHA1::hexdigest(new_data.values.map(&:to_s).sort.to_s)
          Fingerprint.add(user_id, "#{type}-simple", new_hash, new_data)
        end
      end
    end

    # Controller used by administrators to generate reports and handle
    # fingerprints.
    class FingerprintAdminController < ::Admin::AdminController
      requires_plugin PLUGIN_NAME

      def index
        matches = Fingerprint.get_matches

        users = Hash[User.where(id: Set[matches.flatten]).map { |x| [x.id, x] }]

        matches.map! { |match|
          match.map! { |x| BasicUserSerializer.new(users[x], root: false) }
        }

        render json: { matches: matches }
      end

      # Generates a report.
      #
      # Params:
      # +username+::  Name of the user for which the request has been made
      #
      # Returns a hash containing all user fingerprints and a list of
      # matching users having similar fingerprints.
      def report
        user = User.where(username: params[:username]).first
        fingerprints = Fingerprint.get_fingerprints(user.id)

        # Looking up all matching users and augmenting original fingerprint
        # data.
        matches = fingerprints.map { |f| f[:matches] }.reduce(Set[], :merge)
        matches = Hash[User.where(id: matches).map { |x| [x.id, x] }]
        fingerprints.each { |f|
          f[:matches].map! { |x| BasicUserSerializer.new(matches[x], root: false) }
        }

        render json: {
          user: BasicUserSerializer.new(user, root: false),
          fingerprints: fingerprints,
          matches: serialize_data(matches.values, BasicUserSerializer),
        }
      end

      # Adds a new pair of ignored users.
      #
      # Params:
      # +username+::        Name of the first user of the pair
      # +other_username+::  Name of the second user of the pair
      def ignore
        users = User.where(username: [params[:username], params[:other_username]]).pluck(:id)

        Fingerprint.ignore(users[0], users[1])
      end
    end
  end

  DiscourseFingerprint::Engine.routes.draw do
    post '/fingerprint'                      => 'fingerprint#index'

    get  '/admin/plugins/fingerprint'        => 'fingerprint_admin#index'
    get  '/admin/plugins/fingerprint/report' => 'fingerprint_admin#report'
    post '/admin/plugins/fingerprint/ignore' => 'fingerprint_admin#ignore'
  end

  Discourse::Application.routes.append do
    mount ::DiscourseFingerprint::Engine, at: '/'
  end

end
