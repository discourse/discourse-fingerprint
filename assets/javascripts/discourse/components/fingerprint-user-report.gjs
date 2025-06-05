import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class FingerprintUserReport extends Component {
  @discourseComputed("users")
  usersArray(users) {
    return Object.values(users);
  }

  <template>
    <div class="section">
      <div class="section-title">
        <h2>
          {{i18n "fingerprint.matches_for"}}
          <UserLink @user={{this.user}}>
            {{avatar this.user imageSize="medium"}}
            {{this.user.username}}
          </UserLink>
        </h2>
      </div>
      <div class="section-body">
        {{#if this.usersArray.length}}
          <p>{{i18n
              "fingerprint.matches_found"
              count=this.usersArray.length
            }}</p>

          <table>
            <thead>
              <tr>
                <th>{{i18n "fingerprint.results.matching_user"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each this.usersArray as |user|}}
                <tr>
                  <td>
                    <UserLink @user={{user}}>
                      {{avatar user imageSize="small"}}
                      {{user.username}}
                    </UserLink>
                  </td>
                  <td>
                    {{#if user.ignored}}
                      <a href {{on "click" (fn this.ignore user "yes")}}>{{icon
                          "user"
                        }}
                        {{i18n "js.fingerprint.unignore"}}</a>
                    {{else}}
                      <a href {{on "click" (fn this.ignore user)}}>{{icon
                          "user-slash"
                        }}
                        {{i18n "js.fingerprint.ignore"}}</a>
                    {{/if}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          {{i18n "fingerprint.matches_not_found"}}
        {{/if}}
      </div>
    </div>

    <div class="section">
      <div class="section-title">
        <h2>{{i18n "fingerprint.details"}}</h2>
      </div>
      <div class="section-body">
        {{#if this.fingerprints.length}}
          <table>
            <thead>
              <tr>
                <th></th>
                <th>{{i18n "fingerprint.results.hash"}}</th>
                <th>{{i18n "fingerprint.results.first_seen"}}</th>
                <th>{{i18n "fingerprint.results.last_seen"}}</th>
                <th>{{i18n "fingerprint.results.matches"}}</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each this.fingerprints as |fingerprint|}}
                <tr>
                  <td>{{icon fingerprint.device_type}}</td>
                  <td>
                    <small>
                      {{fingerprint.name}}
                      {{#if fingerprint.is_common}}
                        <span
                          data-tooltip={{i18n "fingerprint.common_device"}}
                        >{{icon "layer-group"}}</span>
                      {{/if}}
                    </small>
                    <br />
                    {{fingerprint.value}}
                  </td>
                  <td>{{formatDate fingerprint.created_at}}</td>
                  <td>{{formatDate fingerprint.updated_at}}</td>
                  <td>
                    <p>
                      {{#each fingerprint.users as |u|}}
                        {{#unless u.ignored}}
                          <UserLink @user={{u}}>
                            {{avatar u imageSize="small"}}
                          </UserLink>
                        {{/unless}}
                      {{/each}}
                    </p>
                  </td>
                  <td class="details-col">
                    {{#if fingerprint.hidden}}
                      <a
                        href
                        {{on "click" (fn this.flag "hide" fingerprint "yes")}}
                        title={{i18n "js.fingerprint.unhide"}}
                      >{{icon "far-eye"}}</a>
                    {{else}}
                      <a
                        href
                        {{on "click" (fn this.flag "hide" fingerprint)}}
                        title={{i18n "js.fingerprint.hide"}}
                      >{{icon "eye-slash"}}</a>
                    {{/if}}
                    {{#if fingerprint.silenced}}
                      <a
                        href
                        {{on
                          "click"
                          (fn this.flag "silence" fingerprint "yes")
                        }}
                        title={{i18n "js.fingerprint.unsilence"}}
                      >{{icon "microphone"}}</a>
                    {{else}}
                      <a
                        href
                        class="silence"
                        {{on "click" (fn this.flag "silence" fingerprint)}}
                        title={{i18n "js.fingerprint.silence"}}
                      >{{icon "microphone-slash"}}</a>
                    {{/if}}
                    {{#if fingerprint.data}}
                      <a
                        href
                        {{on
                          "click"
                          (fn this.showFingerprintData fingerprint.data)
                        }}
                        title={{i18n "js.fingerprint.details"}}
                      >{{icon "info"}}</a>
                    {{/if}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{else}}
          {{i18n "fingerprint.none"}}
        {{/if}}
      </div>
    </div>
  </template>
}
