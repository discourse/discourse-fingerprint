import Route from "@ember/routing/route";

export default Route.extend({
  controllerName: "fingerprintReport",
  templateName: "fingerprintReport",

  setupController(controller) {
    controller.update(controller.username);
  },
});
