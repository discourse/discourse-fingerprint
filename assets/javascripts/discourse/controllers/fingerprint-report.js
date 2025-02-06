import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import FingerprintDetails from "../components/modal/fingerprint-details";

export default class FingerprintReportController extends Controller {
  @service modal;

  queryParams = ["username"];

  username = null;
  user = null;
  matches = [];
  fingerprints = [];

  init() {
    super.init(...arguments);
    this.update();
  }

  @discourseComputed("user", "username")
  showReport(user, username) {
    return user && username;
  }

  update(username) {
    this.setProperties({ fingerprints: [] });

    if (username) {
      return ajax("/admin/plugins/fingerprint/user_report", {
        type: "GET",
        data: { username },
      }).then((response) => {
        const ignoredIdsSet = new Set(response.ignored_ids);

        const users = {};
        Object.values(response.users).forEach((user) => {
          user.ignored = ignoredIdsSet.has(user.id);
          users[user.id] = EmberObject.create(user);
        });

        const fingerprints = response.fingerprints.map((fingerprint) => {
          fingerprint.user_ids = fingerprint.user_ids || [];
          fingerprint.users = fingerprint.user_ids.map((id) => users[id]);
          return EmberObject.create(fingerprint);
        });

        this.setProperties({
          user: response.user,
          users,
          fingerprints,
        });
      });
    } else {
      return ajax("/admin/plugins/fingerprint").then((response) => {
        const users = {};
        Object.values(response.users).forEach((user) => {
          users[user.id] = EmberObject.create(user);
        });

        const fingerprints = response.fingerprints.map((fingerprint) => {
          fingerprint.user_ids = fingerprint.user_ids || [];
          fingerprint.users = fingerprint.user_ids.map((id) => users[id]);
          return EmberObject.create(fingerprint);
        });

        this.setProperties({
          fingerprints,
          flagged: response.flagged.map((o) => EmberObject.create(o)),
        });
      });
    }
  }

  @action
  updateUsername(selected) {
    this.set("username", selected.firstObject);
    this.update(selected.firstObject);
  }

  @action
  viewReportForUser(user) {
    this.set("username", user.username);
    return this.update(user.username);
  }

  @action
  showFingerprintData(data) {
    const dataStr = {};
    Object.keys(data).forEach((key) => {
      dataStr[key] =
        data[key] !== null && typeof data[key] === "object"
          ? JSON.stringify(data[key])
          : data[key];
    });
    this.modal.show(FingerprintDetails, { model: { data: dataStr } });
  }

  @action
  flag(type, fingerprint, remove) {
    return ajax("/admin/plugins/fingerprint/flag", {
      type: "PUT",
      data: { type, value: fingerprint.value, remove },
    }).then(() => {
      if (type === "hide") {
        fingerprint.set("hidden", !remove);
      } else if (type === "silence") {
        fingerprint.set("silenced", !remove);
      }
    });
  }

  @action
  ignore(otherUser, remove) {
    return ajax("/admin/plugins/fingerprint/ignore", {
      type: "POST",
      data: {
        username: this.username,
        other_username: otherUser.username,
        remove,
      },
    }).then(() => {
      otherUser.set("ignored", !remove);
    });
  }
}
