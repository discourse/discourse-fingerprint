import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default class FingerprintUserReport extends Component {
  @discourseComputed("users")
  usersArray(users) {
    return Object.values(users);
  }
}
