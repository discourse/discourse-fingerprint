import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const FingerprintDetails = <template>
  <DModal @title={{i18n "fingerprint.details"}} @closeModal={{@closeModal}}>
    <:body>
      <table class="fingerprint">
        <tbody>
          {{#each-in @model.data as |key value|}}
            <tr>
              <td class="key">{{key}}</td>
              <td class="value">{{value}}</td>
            </tr>
          {{/each-in}}
        </tbody>
      </table>
    </:body>
  </DModal>
</template>;

export default FingerprintDetails;
