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
      loadScript(
        "/plugins/discourse-fingerprint/javascripts/fingerprintjs2.js"
      ).then(() => {
        const options = { excludeEnumerateDevices: true };
        /* global Fingerprint2 */
        new Fingerprint2(options).get(function(result, components) {
          // Converting components array to a map.
          let componentsMap = {};
          components.forEach(e => {
            componentsMap[e.key] = e.value;
          });

          ajax("/fingerprint", {
            type: "POST",
            data: {
              type: "fingerprintjs2",
              hash: result,
              data: componentsMap
            }
          });
        });
      });
    }, 3000);
  }
};
