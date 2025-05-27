import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

export default class FingerprintFlagged extends Component {
  <template>
    <div class="section">
      <div class="section-title">
        <h2>{{i18n "fingerprint.flagged"}}</h2>
      </div>
      <div class="section-body">
        {{htmlSafe (i18n "fingerprint.flagged_instructions")}}

        {{#if this.flagged.length}}
          <table>
            <thead>
              <tr>
                <th>{{i18n "fingerprint.results.hash"}}</th>
                <th>{{i18n "fingerprint.results.matches"}}</th>
                <th></th>
                <th></th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {{#each this.flagged as |fingerprint|}}
                <tr>
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
                  <td>{{fingerprint.count}}</td>
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
              {{/each}}
            </tbody>
          </table>
        {{else}}
          {{i18n "fingerprint.flagged_not_found"}}
        {{/if}}
      </div>
    </div>
  </template>
}
