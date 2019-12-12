export default Discourse.Route.extend({
  controllerName: "fingerprintReport",

  renderTemplate() {
    this.render("fingerprintReport");
  },

  setupController(controller) {
    controller.update(controller.username);
  }
});
