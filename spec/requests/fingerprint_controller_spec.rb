# frozen_string_literal: true

require 'rails_helper'

describe DiscourseFingerprint::FingerprintController do
  let(:user) { Fabricate(:user) }

  context '#index' do
    it 'does not work when not logged in' do
      sign_in(user)

      expect {
        post '/fingerprint',
          params: { data: { foo: 'bar', audio: 'baz' }.to_json },
          headers: { 'User-Agent' => 'Discourse' }
      }.to change { Fingerprint.count }.by(4)

      expect(response.status).to eq(200)
      expect(response.headers['Set-Cookie']).to start_with('fp=')
    end
  end
end
