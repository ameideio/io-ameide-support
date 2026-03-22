require 'rails_helper'

RSpec.describe Custom::AmeideOidcCallbacksController, type: :controller do
  describe 'GET #success' do
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

    it 'creates or updates the user from the callback auth hash' do
      with_modified_env(
        FRONTEND_URL: 'http://test.host',
        AMEIDE_OIDC_REQUIRED_ROLES: 'support-agent',
        AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name
      ) do
        request.env['omniauth.auth'] = auth_hash

        get :success

        expect(response).to redirect_to(%r{\Ahttp://test\.host/app/login\?email=.+&sso_auth_token=.+\z})

        user = User.from_email(user_email)
        expect(user).to be_present
        expect(user.provider).to eq('ameide_oidc')
        expect(user.accounts).to include(account)
      end
    end

    it 'fails closed when omniauth auth is missing' do
      with_modified_env(FRONTEND_URL: 'http://test.host') do
        get :success

        expect(response).to redirect_to('http://test.host/app/login?error=ameide-oidc-authentication-failed')
      end
    end
  end

  describe 'GET #failure' do
    it 'redirects back to the support login shell' do
      with_modified_env(FRONTEND_URL: 'http://test.host') do
        get :failure

        expect(response).to redirect_to('http://test.host/app/login?error=ameide-oidc-authentication-failed')
      end
    end
  end
end
