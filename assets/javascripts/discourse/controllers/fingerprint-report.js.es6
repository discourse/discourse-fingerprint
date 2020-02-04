import Controller from "@ember/controller";
import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import showModal from "discourse/lib/show-modal";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  queryParams: ["username"],

  username: "",

  user: null,
  matches: [],
  fingerprints: [],

  @computed("user", "username")
  showReport(user, username) {
    return user && username;
  },

  init() {
    this._super(...arguments);
    this.update();
  },

  update(username) {
    this.setProperties({ fingerprints: [] });

    if (username) {
      return ajax("/admin/plugins/fingerprint/user_report", {
        type: "GET",
        data: { username }
      }).then(response => {
        const ignoredIdsSet = new Set(response.ignored_ids);

        const users = {};
        Object.values(response.users).forEach(user => {
          user.ignored = ignoredIdsSet.has(user.id);
          users[user.id] = EmberObject.create(user);
        });

        const fingerprints = response.fingerprints.map(fingerprint => {
          fingerprint.user_ids = fingerprint.user_ids || [];
          fingerprint.users = fingerprint.user_ids.map(id => users[id]);
          return EmberObject.create(fingerprint);
        });

        this.setProperties({
          user: response.user,
          users,
          fingerprints
        });
      });
    } else {
      return ajax("/admin/plugins/fingerprint").then(response => {
        const users = {};
        Object.values(response.users).forEach(user => {
          users[user.id] = EmberObject.create(user);
        });

        const fingerprints = response.fingerprints.map(fingerprint => {
          fingerprint.user_ids = fingerprint.user_ids || [];
          fingerprint.users = fingerprint.user_ids.map(id => users[id]);
          return EmberObject.create(fingerprint);
        });

        this.setProperties({
          fingerprints,
          flagged: response.flagged.map(o => EmberObject.create(o))
        });
      });
    }
  },

  actions: {
    onChange() {
      return this.update(this.username);
    },

    viewReportForUser(user) {
      this.set("username", user.username);
      return this.update(user.username);
    },

    showFingerprintData(data) {
      showModal("fingerprint-details").setProperties({ data });
    },

    flag(type, fingerprint, remove) {
      return ajax("/admin/plugins/fingerprint/flag", {
        type: "PUT",
        data: { type, value: fingerprint.value, remove }
      }).then(() => {
        if (type === "hide") {
          fingerprint.set("hidden", !remove);
        } else if (type === "silence") {
          fingerprint.set("silenced", !remove);
        }
      });
    },

    ignore(otherUser, remove) {
      return ajax("/admin/plugins/fingerprint/ignore", {
        type: "POST",
        data: {
          username: this.username,
          other_username: otherUser.username,
          remove
        }
      }).then(() => {
        otherUser.set("ignored", !remove);
      });
    }
  }
});
