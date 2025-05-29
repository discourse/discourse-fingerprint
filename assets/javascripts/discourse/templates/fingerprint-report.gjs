import { hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import FingerprintFlagged from "../components/fingerprint-flagged";
import FingerprintLatestMatches from "../components/fingerprint-latest-matches";
import FingerprintUserReport from "../components/fingerprint-user-report";

export default RouteTemplate(
  <template>
    <div class="dashboard-next dashboard-fingerprint">
      <div class="section">
        <div class="section">
          <div class="section-title">
            <h2>{{i18n "fingerprint.title"}}</h2>
          </div>

          <div class="section-body">
            <EmailGroupUserChooser
              @value={{@controller.username}}
              @onChange={{@controller.updateUsername}}
              @options={{hash
                maximum=1
                filterPlaceholder="user.username.title"
              }}
            />
          </div>
        </div>
      </div>

      {{#if @controller.showReport}}
        <FingerprintUserReport
          @user={{@controller.user}}
          @users={{@controller.users}}
          @fingerprints={{@controller.fingerprints}}
          @ignore={{@controller.ignore}}
          @flag={{@controller.flag}}
          @showFingerprintData={{@controller.showFingerprintData}}
        />
      {{else}}
        <FingerprintLatestMatches
          @fingerprints={{@controller.fingerprints}}
          @viewReportForUser={{@controller.viewReportForUser}}
          @flag={{@controller.flag}}
          @showFingerprintData={{@controller.showFingerprintData}}
        />

        <FingerprintFlagged
          @flagged={{@controller.flagged}}
          @flag={{@controller.flag}}
          @showFingerprintData={{@controller.showFingerprintData}}
        />
      {{/if}}
    </div>
  </template>
);
