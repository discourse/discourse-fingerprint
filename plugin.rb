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

  module ::DiscourseFingerprint
    PLUGIN_NAME = 'discourse-fingerprint'

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
      engine_name DiscourseFingerprint::PLUGIN_NAME
      isolate_namespace DiscourseFingerprint
    end

    # Manages user fingerprints and handles conflicts.
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
    # Conflicts are array containing user IDs that have the same fingerprint.
    # Two fingerprints are the same if they have the same type and same hash.
    #
    # To store fingerprints and conflicts, multiple +PluginStore+ keys are
    # used imitating a bidirectional map between users and fingerprints. The
    # following keys are used:
    #
    #   +user_%+::    Used to store arrays of fingerprint objects.
    #                 Key is parametrized by user ID.
    #
    #   +hash_%_%+::  Used to store conflicts for a specific fingerprint.
    #                 Key is parametrized by type and hash value.
    #
    #   +conflict+::  Used to store latest +hash_%_%+ keys that are associated
    #                 with conflicts involving more than 1 user.
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
          fingerprints[idx][:last_time] = Time.now.to_s
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
        Store.set(user_key, fingerprints << {
          type:       type,
          hash:       hash,
          data:       data,
          first_time: Time.now.to_s,
          last_time:  Time.now.to_s,
        })

        # Assigning the user to the new fingerprint.
        users = Store.get(hash_key) || []
        users << user_id
        Store.set(hash_key, users)

        # Saving if conflicts.
        if users.size > 1
          conflicts = Store.get('conflicts') || []
          if !conflicts.include?(hash_key)
            conflicts << hash_key
            Store.set('conflicts', conflicts.last(SiteSetting.max_fingerprint_conflicts))
          end
        end

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

        # Remove conflict if there are not at least 2 fingerprints remaining.
        if users.size < 2
          conflicts = Store.get('conflicts') || []
          if conflicts.include?(hash_key)
            conflicts.delete(hash_key)
            Store.set('conflicts', conflicts)
          end
        end

        nil
      end

      # Ignores all conflicts of +user_id_a+ with +user_id_b+.
      #
      # Params:
      # +user_a+::  First user of the pair
      # +user_b+::  Second user of the pair
      # +add+::     Whether this is adds or removes a ignore entry
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
      # Each fingerprint object is augmented with an array of conflicts.
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
        conflicts = Store.get_all(hash_keys)
        fingerprints.each { |f|
          hash_key = "hash_#{f[:type]}_#{f[:hash]}"
          f[:conflicts] = (conflicts[hash_key] || []) - ignores
        }

        fingerprints
      end

      # Gets latest conflicts.
      #
      # This method shall not return more than +SiteSettings.max_fingerprint_conflicts+.
      #
      # Returns a list of conflicts.
      def self.get_conflicts
        conflicts = Store.get('conflicts') || []

        Store.get_all(conflicts).values
      end

    end

    # Controller used to record new user fingerprints.
    class FingerprintController < ::ApplicationController
      before_action :ensure_logged_in
      skip_before_action :check_xhr

      def index
        user_id = current_user.id
        type    = params.require(:type)
        hash    = params.require(:hash)
        data    = params.require(:data)

        DiscourseFingerprint::Fingerprint.add(user_id, type, hash, data)
      end
    end

    # Controller used by administrators to generate reports and handle
    # fingerprints.
    class FingerprintAdminController < ::Admin::AdminController

      def index
        conflicts = DiscourseFingerprint::Fingerprint.get_conflicts

        users = Set[conflicts.flatten]
        users = Hash[User.where(id: users).map { |x| [x.id, x] }]

        conflicts.map! { |conflict|
          conflict.map! { |x| users[x] }
        }

        render json: { conflicts: conflicts }
      end

      # Generates a report.
      #
      # Params:
      # +user+::  Name of the user for which the request has been made
      #
      # Returns a hash containing all user fingerprints and a list of
      # conflicting users having similar fingerprints.
      def report
        user_id = User.where(username: params[:user]).pluck(:id).first
        fingerprints = DiscourseFingerprint::Fingerprint.get_fingerprints(user_id)

        # Looking up all conflicting users and augmenting original fingerprint
        # data.
        conflicts = fingerprints.map { |f| f[:conflicts] }.reduce(Set[], :merge)
        conflicts = Hash[User.where(id: conflicts).map { |x| [x.id, x] }]
        fingerprints.each { |f|
          f[:conflicts].map! { |x| conflicts[x] }
        }

        render json: {
          fingerprints: fingerprints,
          conflicts: conflicts.values,
        }
      end

      # Adds a new pair of ignored users.
      #
      # Params:
      # +user_a+::  First user of the pair
      # +user_b+::  Second user of the pair
      def ignore
        users = User.where(username: [params[:user], params[:other_user]]).pluck(:id)

        DiscourseFingerprint::Fingerprint.ignore(users[0], users[1])
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
