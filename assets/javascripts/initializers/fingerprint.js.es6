import { ajax } from "discourse/lib/ajax";
import loadScript from "discourse/lib/load-script";

export default {
  name: "fingerprint",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    const user = container.lookup("current-user:main");
    if (!siteSettings.fingerprint_enabled || !user) {
      return;
    }

    // Wait for 3 seconds before fingerprinting user to let the browser use
    // resources for more important tasks (i.e. resource loading, rendering).
    Ember.run.later(() => {
      loadScript("/plugins/discourse-fingerprint/javascripts/fp2.js").then(
        () => {
          /* global Fingerprint2 */
          Fingerprint2.get(components => {
            // Converting components array to a map.
            let componentsMap = {};
            components.forEach(e => {
              componentsMap[e.key] = e.value;
            });

            ajax("/fingerprint", {
              type: "POST",
              data: {
                type: "fingerprintjs2_v2",
                data: JSON.stringify(componentsMap)
              }
            });
          });
        }
      );
    }, 3000);
  }
};
