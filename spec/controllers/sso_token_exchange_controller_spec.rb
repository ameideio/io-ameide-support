require 'rails_helper'

RSpec.describe SsoTokenExchangeController, type: :request do
  describe 'POST /auth/sso/exchange' do
    it 'returns the cookie value as JSON and clears the cookie' do
      cookies[:sso_auth_token] = 'token-abc'

      post '/auth/sso/exchange'

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['sso_auth_token']).to eq('token-abc')
      # After consumption the response clears the cookie.
      expect(response.headers['Set-Cookie']).to match(/sso_auth_token=;/)
    end

    it 'returns 204 when no SSO cookie is present' do
      post '/auth/sso/exchange'

      expect(response).to have_http_status(:no_content)
    end
  end
end
