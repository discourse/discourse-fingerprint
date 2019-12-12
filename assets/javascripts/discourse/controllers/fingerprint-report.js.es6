import { ajax } from "discourse/lib/ajax";
import computed from "ember-addons/ember-computed-decorators";
import showModal from "discourse/lib/show-modal";

export default Ember.Controller.extend({
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
    this.setProperties({ fingerprints: [], matches: [] });

    if (username) {
      return ajax("/admin/plugins/fingerprint/user_report", {
        type: "GET",
        data: { username }
      }).then(response => {
        const { user, fingerprints } = response;

        const matches = [];
        const matchesSet = new Set();
        fingerprints.forEach(fp =>
          fp.matches.forEach(u => {
            if (!matchesSet.has(u.id)) {
              matchesSet.add(u.id);
              matches.push(u);
            }
          })
        );

        this.setProperties({ user, fingerprints, matches });
      });
    } else {
      return ajax("/admin/plugins/fingerprint", {
        type: "GET"
      }).then(response => {
        this.set("matches", response.matches);
        this.set("flagged", response.flagged);
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

    showDetails(fingerprint) {
      showModal("fingerprint-details").setProperties({ fingerprint });
    },

    flag(type, value, remove) {
      return ajax("/admin/plugins/fingerprint/flag", {
        type: "PUT",
        data: { type, value, remove }
      }).then(() => this.send("onChange"));
    },

    ignore(other_username) {
      return ajax("/admin/plugins/fingerprint/ignore", {
        type: "POST",
        data: { username: this.username, other_username }
      }).then(() => this.send("onChange"));
    }
  }
});
