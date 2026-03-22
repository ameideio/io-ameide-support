require 'rails_helper'

RSpec.describe DeviseOverrides::OmniauthCallbacksController, type: :controller do
  include Devise::Test::ControllerHelpers

  before do
    request.env['devise.mapping'] = Devise.mappings[:user]
  end

  describe 'GET #omniauth_success' do
    let(:account_name) { "Ameide OIDC #{SecureRandom.hex(4)}" }
    let(:user_email) { "agent-#{SecureRandom.hex(4)}@ameide.io" }
    let!(:account) { create(:account, name: account_name) }

    let(:auth_hash) do
      OmniAuth::AuthHash.new(
        provider: 'ameide_oidc',
        uid: 'oidc-user-1',
        info: {
          name: 'Ameide Agent',
          email: user_email,
          first_name: 'Ameide',
          last_name: 'Agent',
          roles: ['support-agent']
        },
        extra: {
          raw_info: {
            sub: 'oidc-user-1',
            email: user_email,
            realm_access: {
              roles: ['support-agent']
            }
          }
        }
      )
    end

    it 'falls back to request env auth hash for direct provider callbacks' do
      with_modified_env(
        FRONTEND_URL: 'http://test.host',
        AMEIDE_OIDC_REQUIRED_ROLES: 'support-agent',
        AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name
      ) do
        request.env['omniauth.auth'] = auth_hash

        get :omniauth_success, params: { provider: 'ameide_oidc' }

        expect(response).to redirect_to(%r{\Ahttp://test\.host/app/login\?email=.+&sso_auth_token=.+\z})

        user = User.from_email(user_email)
        expect(user).to be_present
        expect(user.provider).to eq('ameide_oidc')
        expect(user.accounts).to include(account)
      end
    end
  end
end
