require 'rails_helper'

describe '/app/login', type: :request do
  context 'without DEFAULT_LOCALE' do
    it 'redirects to ameide oidc' do
      get '/app/login'
      expect(response).to redirect_to('/auth/ameide_oidc')
    end
  end

  context 'with DEFAULT_LOCALE' do
    it 'still redirects to ameide oidc' do
      with_modified_env DEFAULT_LOCALE: 'pt_BR' do
        get '/app/login'
        expect(response).to redirect_to('/auth/ameide_oidc')
      end
    end
  end

  context 'with sso or error query parameters' do
    it 'renders the dashboard shell for callback completion' do
      get '/app/login', params: { email: 'agent@ameide.io', sso_auth_token: 'token' }

      expect(response).to have_http_status(:success)
    end

    it 'renders the dashboard shell for auth errors' do
      get '/app/login', params: { error: 'ameide-oidc-access-denied' }

      expect(response).to have_http_status(:success)
    end
  end

  context 'with non-HTML format' do
    it 'returns not acceptable for JSON with error message' do
      get '/app/login', headers: { 'Accept' => 'application/json' }
      expect(response).to have_http_status(:not_acceptable)
      expect(response.parsed_body).to eq({ 'error' => 'Please use API routes instead of dashboard routes for JSON requests' })
    end
  end

  # Routes are loaded once on app start
  # hence Rails.application.reload_routes! is used in this spec
  # ref : https://stackoverflow.com/a/63584877/939299
  context 'with CW_API_ONLY_SERVER true' do
    it 'returns 404' do
      with_modified_env CW_API_ONLY_SERVER: 'true' do
        Rails.application.reload_routes!
        get '/app/login'
        expect(response).to have_http_status(:not_found)
      end
      Rails.application.reload_routes!
    end
  end
end
