require 'rails_helper'

RSpec.describe 'Custom Ameide OIDC Session Protection', type: :request do
  let(:user_email) { "agent-#{SecureRandom.hex(4)}@ameide.io" }
  let!(:account) { create(:account, name: "Ameide OIDC #{SecureRandom.hex(4)}") }
  let!(:user) { create(:user, email: user_email, provider: 'ameide_oidc', password: 'Password1!', account: account) }
  let!(:email_user) { create(:user, email: "email-#{SecureRandom.hex(4)}@ameide.io", provider: 'email', password: 'Password1!', account: account) }

  it 'blocks password login for ameide oidc users' do
    post new_user_session_url, params: { email: user.email, password: 'Password1!' }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body['errors']).to include('Use Ameide SSO to sign in.')
  end

  it 'blocks password login for non-oidc users as well' do
    post new_user_session_url, params: { email: email_user.email, password: 'Password1!' }, as: :json

    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body['errors']).to include('Use Ameide SSO to sign in.')
  end

  it 'allows sso token login for ameide oidc users' do
    valid_token = user.generate_sso_auth_token

    post new_user_session_url, params: { email: user.email, sso_auth_token: valid_token }, as: :json

    expect(response).to have_http_status(:success)
  end

  it 'redirects ameide oidc logout through keycloak' do
    with_modified_env \
      AMEIDE_OIDC_ISSUER_URL: 'https://sso.example.com/realms/ameide',
      AMEIDE_OIDC_CLIENT_ID: 'io-ameide-support',
      FRONTEND_URL: 'https://support.example.com' do
      get '/auth/ameide_oidc/logout'

      expect(response).to redirect_to(
        'https://sso.example.com/realms/ameide/protocol/openid-connect/logout?' \
        'client_id=io-ameide-support&post_logout_redirect_uri=https%3A%2F%2Fsupport.example.com%2Fapp%2Flogin'
      )
    end
  end
end
