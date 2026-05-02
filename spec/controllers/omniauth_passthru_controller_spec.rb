require 'rails_helper'

RSpec.describe OmniauthPassthruController, type: :request do
  describe 'GET /omniauth/:provider' do
    it 'renders the auto-submitting passthru when Sec-Fetch-Site is same-origin' do
      get '/omniauth/ameide_oidc', headers: { 'Sec-Fetch-Site' => 'same-origin' }
      expect(response).to have_http_status(:ok)
    end

    it 'renders the auto-submitting passthru when Sec-Fetch-Site is same-site' do
      get '/omniauth/ameide_oidc', headers: { 'Sec-Fetch-Site' => 'same-site' }
      expect(response).to have_http_status(:ok)
    end

    it 'renders the auto-submitting passthru when Sec-Fetch-Site is none (direct navigation)' do
      get '/omniauth/ameide_oidc', headers: { 'Sec-Fetch-Site' => 'none' }
      expect(response).to have_http_status(:ok)
    end

    it 'renders the auto-submitting passthru when Sec-Fetch-Site header is absent (legacy clients)' do
      get '/omniauth/ameide_oidc'
      expect(response).to have_http_status(:ok)
    end

    it 'rejects requests when Sec-Fetch-Site is cross-site' do
      get '/omniauth/ameide_oidc', headers: { 'Sec-Fetch-Site' => 'cross-site' }
      expect(response).to have_http_status(:forbidden)
    end
  end
end
