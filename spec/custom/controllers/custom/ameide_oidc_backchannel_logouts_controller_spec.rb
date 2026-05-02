require 'rails_helper'
require 'jwt'

RSpec.describe Custom::AmeideOidcBackchannelLogoutsController, type: :request do
  let(:issuer_url) { 'https://sso.example.com/realms/ameide' }
  let(:client_id) { 'io-ameide-support' }
  let(:jwks_uri) { "#{issuer_url}/protocol/openid-connect/certs" }
  let(:rsa_private) { OpenSSL::PKey::RSA.generate(2048) }
  let(:kid) { 'ameide-test-key-1' }

  let(:jwk) do
    JWT::JWK.new(rsa_private, kid: kid).export.merge('alg' => 'RS256', 'use' => 'sig')
  end

  let(:account) { create(:account, name: 'Ameide') }
  let!(:user) do
    u = create(:user, provider: 'ameide_oidc')
    AccountUser.create!(account: account, user: u, role: :agent)
    # `set_password_and_uid` (on: :create) overwrites uid with email, so we
    # have to write the OIDC `sub` value back afterwards. Bypass the DTA
    # `destroy_expired_tokens` save-callback (which expects `expiry`) by
    # writing both columns directly.
    u.update_columns(uid: 'oidc-user-1', tokens: { 'client-1' => { 'token' => 'x', 'expiry' => 1.hour.from_now.to_i } }) # rubocop:disable Rails/SkipsModelValidations
    u.reload
  end

  # Replace the test :null_store with an in-memory store so the JWKS cache
  # and JTI replay guard actually round-trip during the spec.
  around do |example|
    previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
  ensure
    Rails.cache = previous_cache
  end

  before do
    stub_request(:get, jwks_uri).to_return(
      status: 200,
      body: { keys: [jwk] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def with_oidc_env(&)
    with_modified_env(
      AMEIDE_OIDC_ISSUER_URL: issuer_url,
      AMEIDE_OIDC_CLIENT_ID: client_id,
      AMEIDE_OIDC_JWKS_URI: jwks_uri,
      &
    )
  end

  def build_logout_token(overrides = {})
    payload = {
      iss: issuer_url,
      aud: client_id,
      iat: Time.now.to_i,
      jti: SecureRandom.uuid,
      sub: 'oidc-user-1',
      events: { 'http://schemas.openid.net/event/backchannel-logout' => {} }
    }.merge(overrides)
    JWT.encode(payload, rsa_private, 'RS256', kid: kid, typ: 'logout+jwt')
  end

  it 'invalidates the user devise_token_auth tokens on a valid logout_token' do
    with_oidc_env do
      post '/auth/ameide_oidc/backchannel-logout', params: { logout_token: build_logout_token }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({})
      expect(user.reload.tokens).to eq({})
    end
  end

  it 'returns 200 when the user is not found (per spec)' do
    with_oidc_env do
      token = build_logout_token(sub: 'unknown-user')
      post '/auth/ameide_oidc/backchannel-logout', params: { logout_token: token }

      expect(response).to have_http_status(:ok)
    end
  end

  it 'rejects a logout_token signed with the wrong key' do
    other_key = OpenSSL::PKey::RSA.generate(2048)
    payload = {
      iss: issuer_url, aud: client_id, iat: Time.now.to_i, jti: SecureRandom.uuid, sub: 'oidc-user-1',
      events: { 'http://schemas.openid.net/event/backchannel-logout' => {} }
    }
    forged = JWT.encode(payload, other_key, 'RS256', kid: kid)

    with_oidc_env do
      post '/auth/ameide_oidc/backchannel-logout', params: { logout_token: forged }

      expect(response).to have_http_status(:bad_request)
      expect(user.reload.tokens).not_to eq({})
    end
  end

  it 'rejects a logout_token whose issuer does not match' do
    with_oidc_env do
      token = build_logout_token(iss: 'https://attacker.example.com/realms/evil')
      post '/auth/ameide_oidc/backchannel-logout', params: { logout_token: token }

      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'rejects a logout_token whose audience does not match the client_id' do
    with_oidc_env do
      token = build_logout_token(aud: 'some-other-client')
      post '/auth/ameide_oidc/backchannel-logout', params: { logout_token: token }

      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'rejects a logout_token missing the backchannel-logout event' do
    with_oidc_env do
      token = build_logout_token(events: { 'http://example.com/event/other' => {} })
      post '/auth/ameide_oidc/backchannel-logout', params: { logout_token: token }

      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'rejects a logout_token that contains a nonce claim' do
    with_oidc_env do
      token = build_logout_token(nonce: 'should-not-be-here')
      post '/auth/ameide_oidc/backchannel-logout', params: { logout_token: token }

      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'rejects replays of the same jti within the cache window' do
    with_oidc_env do
      token = build_logout_token

      post '/auth/ameide_oidc/backchannel-logout', params: { logout_token: token }
      expect(response).to have_http_status(:ok)

      post '/auth/ameide_oidc/backchannel-logout', params: { logout_token: token }
      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'returns 400 when logout_token is missing' do
    with_oidc_env do
      post '/auth/ameide_oidc/backchannel-logout', params: {}

      expect(response).to have_http_status(:bad_request)
    end
  end
end
