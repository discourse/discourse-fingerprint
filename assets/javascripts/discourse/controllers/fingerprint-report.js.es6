import { ajax } from "discourse/lib/ajax";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  username: "",

  all_matches: [],

  user: null,
  fingerprints: [],
  matches: [],

  @computed("user", "username")
  showReport(user, username) {
    return user && username;
  },

  init() {
    this._super(...arguments);

    ajax("/admin/plugins/fingerprint", {
      type: "GET"
    }).then(response => {
      this.set("all_matches", response.matches);
    });
  },

  actions: {
    viewReportFor(user) {
      this.set("username", user.username);
    },

    updateReport() {
      const username = this.get("username");
      if (!username) {
        return;
      }

      ajax("/admin/plugins/fingerprint/report", {
        type: "GET",
        data: { username }
      }).then(response => {
        this.setProperties({
          user: response.user,
          matches: response.matches,
          fingerprints: response.fingerprints
        });
      });
    },

    addIgnore(other_username) {
      const username = this.get("username");
      ajax("/admin/plugins/fingerprint/ignore", {
        type: "POST",
        data: { username, other_username }
      }).andThen(() => this.send("updateReport"));
    }
  }
});
