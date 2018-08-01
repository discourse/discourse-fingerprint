import { ajax } from "discourse/lib/ajax";

export default Ember.Controller.extend({
  user: "",

  all_conflicts: [],

  fingerprints: [],
  conflicts: [],

  init() {
    this._super(...arguments);

    ajax("/admin/plugins/fingerprint", {
      type: "GET"
    }).then(response => {
      this.set("all_conflicts", response.conflicts);
    });
  },

  actions: {
    updateReport() {
      const user = this.get("user");
      if (!user) {
        return;
      }

      ajax("/admin/plugins/fingerprint/report", {
        type: "GET",
        data: { user }
      }).then(response => {
        this.setProperties({
          conflicts: response.conflicts,
          fingerprints: response.fingerprints
        });
      });
    },

    addIgnore(other_user) {
      const user = this.get("user");
      ajax("/admin/plugins/fingerprint/ignore", {
        type: "POST",
        data: { user, other_user }
      }).andThen(() => this.send("updateReport"));
    }
  }
});
