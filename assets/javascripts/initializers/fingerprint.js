import { later } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import loadScript from "discourse/lib/load-script";

export default {
  name: "fingerprint",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    const user = container.lookup("service:current-user");
    if (!siteSettings.fingerprint_enabled || !user) {
      return;
    }

    // Wait for 3 seconds before fingerprinting user to let the browser use
    // resources for more important tasks (i.e. resource loading, rendering).
    later(() => {
      loadScript("/plugins/discourse-fingerprint/javascripts/fp.js").then(
        () => {
          /* global FingerprintJS */
          FingerprintJS.load()
            .then((fp) => fp.get())
            .then((result) => {
              const resultMap = {};
              Object.keys(result.components).forEach(
                (key) => (resultMap[key] = result.components[key].value)
              );

              ajax("/fingerprint", {
                type: "POST",
                data: {
                  visitor_id: result.visitorId,
                  version: result.version,
                  data: JSON.stringify(resultMap),
                },
              });
            });
        }
      );
    }, 3000);
  },
};
