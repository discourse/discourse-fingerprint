import Route from "@ember/routing/route";

export default Route.extend({
  controllerName: "fingerprintReport",

  renderTemplate() {
    this.render("fingerprintReport");
  },

  setupController(controller) {
    controller.update(controller.username);
  },
});
