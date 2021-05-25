# frozen_string_literal: true

require 'rails_helper'

describe DiscourseFingerprint::FingerprintController do
  let(:user) { Fabricate(:user) }

  context '#index' do
    it 'saves fingerprints for users' do
      expect {
        post '/fingerprint',
          params: { visitor_id: 'abc', version: '1.0.0', data: { foo: 'bar', audio: 'baz' }.to_json },
          headers: { 'User-Agent' => 'Discourse' }
      }.to change { Fingerprint.count }.by(0)

      expect(response.status).to eq(403)

      sign_in(user)

      expect {
        post '/fingerprint',
          params: { visitor_id: 'abc', version: '1.0.0', data: { foo: 'bar', audio: 'baz' }.to_json },
          headers: { 'User-Agent' => 'Discourse' }
      }.to change { Fingerprint.count }.by(2)

      expect(response.status).to eq(200)

      expect {
        SiteSetting.fingerprint_cookie = true

        post '/fingerprint',
          params: { visitor_id: 'abc', version: '1.0.0', data: { foo: 'bar', audio: 'baz' }.to_json },
          headers: { 'User-Agent' => 'Discourse' }
      }.to change { Fingerprint.count }.by(1)

      expect(response.status).to eq(200)
      expect(response.headers['Set-Cookie']).to start_with('fp=')

      expect {
        SiteSetting.fingerprint_ip = true

        post '/fingerprint',
          params: { visitor_id: 'abc', version: '1.0.0', data: { foo: 'bar', audio: 'baz' }.to_json },
          headers: { 'User-Agent' => 'Discourse' }
      }.to change { Fingerprint.count }.by(1)

      expect(response.status).to eq(200)
    end
  end
end
