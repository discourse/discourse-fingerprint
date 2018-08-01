import { ajax } from 'discourse/lib/ajax';
import loadScript from 'discourse/lib/load-script';

export default {
  name: 'fingerprint',

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    const user = container.lookup('current-user:main');
    if (!siteSettings.fingerprint_enabled || !user) {
      return;
    }

    loadScript('/plugins/discourse-fingerprint/javascripts/fingerprintjs2.js').then(() => {
      // Wait for 3 seconds before fingerprinting user to let the browser use
      // resources for more important tasks (i.e. resource loading, rendering).
      setTimeout(() => {
        var options = { excludeEnumerateDevices: true };
        /* global Fingerprint2 */
        new Fingerprint2(options).get(function(result, components) {
          ajax('/fingerprint', { type: 'POST', data: {
            type: 'fingerprintjs2',
            hash: result,
            data: components,
          }});
        });
      }, 3000);
    });
  }
};
