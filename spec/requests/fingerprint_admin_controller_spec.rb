# frozen_string_literal: true

RSpec.describe DiscourseFingerprint::FingerprintAdminController do
  fab!(:user)
  fab!(:other_user, :user)
  fab!(:admin)

  before { sign_in(admin) }

  describe "#matches" do
    before do
      [user, other_user].each do |u|
        Fingerprint.create!(user: u, name: "audio", value: "abc", data: { audio: "x" }.to_json)
      end
    end

    it "returns the latest matches and the flagged fingerprints" do
      get "/admin/plugins/fingerprint/matches.json"

      expect(response.status).to eq(200)

      body = response.parsed_body
      expect(body.keys).to contain_exactly("fingerprints", "flagged", "users")
      expect(body["fingerprints"].map { |fp| fp["value"] }).to eq(%w[abc])
      expect(body["users"].keys).to contain_exactly(user.id.to_s, other_user.id.to_s)
      expect(body["flagged"]).to eq([])
    end

    it "is not answered by core's /admin/plugins/:plugin_id route" do
      # A bare "/admin/plugins/fingerprint" is claimed by Admin::PluginsController#show,
      # which answers with the plugin metadata instead of the report.
      get "/admin/plugins/fingerprint.json"
      expect(response.parsed_body).to have_key("id")
    end
  end
end
