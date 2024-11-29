import Route from "@ember/routing/route";

export default class AdminPluginsFingerprintRoute extends Route {
  controllerName = "fingerprintReport";
  templateName = "fingerprintReport";

  setupController(controller) {
    controller.update(controller.username);
  }
}
