import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  @discourseComputed("users")
  usersArray(users) {
    return Object.values(users);
  }
});
