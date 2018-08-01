import { ajax } from 'discourse/lib/ajax';
import Fingerprint2 from 'discourse/plugins/discourse-fingerprint/lib/fingerprintjs2';

export default {
  name: 'fingerprint',

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    const user = container.lookup('current-user:main');
    if (!siteSettings.fingerprint_enabled || !user) {
      return;
    }

    // Wait for 3 seconds before fingerprinting user to let the browser use
    // resources for more important tasks (i.e. resource loading, rendering).
    setTimeout(() => {
      var options = { excludeEnumerateDevices: true };
      new Fingerprint2(options).get(function(result, components) {
        ajax('/fingerprint', { type: 'POST', data: {
          type: 'fingerprintjs2',
          hash: result,
          data: components,
        }});
      });
    }, 3000);
  }
};
