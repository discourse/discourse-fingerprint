import Component, { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { and, not } from "truth-helpers";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default class FingerprintLatestMatches extends Component {
  hideCommon = true;

  <template>
    <div class="section">
      <div class="section-title">
        <h2>{{i18n "fingerprint.latest_matches"}}</h2>
      </div>
      <div class="section-body">
        {{htmlSafe
          (i18n
            "fingerprint.latest_matches_instructions"
            algorithm="<a href='https://github.com/Valve/fingerprintjs2'>Fingeprintjs2</a>"
          )
        }}

        {{#if this.fingerprints.length}}
          <table>
            <thead>
              <tr>
                <th></th>
                <th>{{i18n "fingerprint.results.hash"}}</th>
                <th>{{i18n "fingerprint.results.matches"}}</th>
                <th colspan="3">
                  {{Input
                    type="checkbox"
                    id="hide-common"
                    checked=this.hideCommon
                  }}
                  <label for="hide-common">{{i18n
                      "fingerprint.hide_common"
                    }}</label>
                </th>
              </tr>
            </thead>
            <tbody>
              {{#each this.fingerprints as |fingerprint|}}
                {{#if (not (and this.hideCommon fingerprint.is_common))}}
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
                    <td>
                      <small>{{fingerprint.user_ids.length}}</small>
                      {{#each fingerprint.users as |u|}}
                        <UserLink @user={{u}}>
                          {{avatar u imageSize="small"}}
                        </UserLink>
                      {{/each}}
                    </td>
                    <td>
                      {{#if fingerprint.hidden}}
                        <a
                          href
                          {{on "click" (fn this.flag "hide" fingerprint "yes")}}
                        >{{icon "far-eye"}}
                          {{i18n "js.fingerprint.unhide"}}</a>
                      {{else}}
                        <a
                          href
                          {{on "click" (fn this.flag "hide" fingerprint)}}
                        >{{icon "far-eye-slash"}}
                          {{i18n "js.fingerprint.hide"}}</a>
                      {{/if}}
                    </td>
                    <td>
                      {{#if fingerprint.silenced}}
                        <a
                          href
                          {{on
                            "click"
                            (fn this.flag "silence" fingerprint "yes")
                          }}
                        >{{icon "microphone"}}
                          {{i18n "js.fingerprint.unsilence"}}</a>
                      {{else}}
                        <a
                          href
                          class="silence"
                          {{on "click" (fn this.flag "silence" fingerprint)}}
                        >{{icon "microphone-slash"}}
                          {{i18n "js.fingerprint.silence"}}</a>
                      {{/if}}
                    </td>
                    <td>
                      {{#if fingerprint.data}}
                        <a
                          href
                          {{on
                            "click"
                            (fn this.showFingerprintData fingerprint.data)
                          }}
                        >{{icon "info"}} {{i18n "js.fingerprint.details"}}</a>
                      {{/if}}
                    </td>
                  </tr>
                {{/if}}
              {{/each}}
            </tbody>
          </table>
        {{else}}
          {{i18n "fingerprint.matches_not_found"}}
        {{/if}}
      </div>
    </div>
  </template>
}
