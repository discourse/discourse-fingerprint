import { ajax } from "discourse/lib/ajax";

export default Ember.Controller.extend({
  username: "",

  all_matches: [],

  fingerprints: [],
  matches: [],

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
