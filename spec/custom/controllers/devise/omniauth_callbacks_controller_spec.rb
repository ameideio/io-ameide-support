require 'rails_helper'

RSpec.describe 'Custom Ameide OIDC OmniAuth Callbacks', type: :request do
  let(:account_name) { "Ameide OIDC #{SecureRandom.hex(4)}" }
  let(:user_email) { "agent-#{SecureRandom.hex(4)}@ameide.io" }
  let!(:account) { create(:account, name: account_name) }

  def set_omniauth_config(email, roles = ['support-agent'])
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:ameide_oidc] = build_auth_hash(email, roles)
  end

  def build_auth_hash(email, roles)
    OmniAuth::AuthHash.new(
      provider: 'ameide_oidc',
      uid: 'oidc-user-1',
      info: auth_info(email, roles),
      extra: { raw_info: auth_raw_info(email, roles) }
    )
  end

  def auth_info(email, roles)
    {
      name: 'Ameide Agent',
      email: email,
      first_name: 'Ameide',
      last_name: 'Agent',
      roles: roles
    }
  end

  def auth_raw_info(email, roles)
    {
      sub: 'oidc-user-1',
      email: email,
      email_verified: true,
      realm_access: {
        roles: roles
      }
    }
  end

  it 'creates a new ameide oidc user and redirects through the sso token flow', :aggregate_failures do
    with_modified_env(
      FRONTEND_URL: 'http://www.example.com',
      AMEIDE_OIDC_REQUIRED_ROLES: 'support-agent',
      AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name
    ) do
      set_omniauth_config(user_email)

      get '/omniauth/ameide_oidc/callback'

      expect(response).to redirect_to('http://www.example.com/auth/ameide_oidc/callback')
      follow_redirect!
      expect(response).to redirect_to(%r{/app/login\?email=[^&]+$})
      expect(response.headers['Set-Cookie']).to match(/sso_auth_token=/)
      expect(response.headers['Set-Cookie']).to match(%r{path=/app/login}i)
      expect(response.headers['Set-Cookie']).to match(/HttpOnly/i)
      expect(response.headers['Set-Cookie']).to match(/SameSite=Lax/i)

      user = User.from_email(user_email)
      expect(user).to be_present
      expect(user.provider).to eq('ameide_oidc')
      expect(user.accounts).to include(account)
    end
  end

  it 'rejects an unauthorized ameide oidc user' do
    with_modified_env(
      FRONTEND_URL: 'http://www.example.com',
      AMEIDE_OIDC_REQUIRED_ROLES: 'support-admin',
      AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name
    ) do
      set_omniauth_config(user_email, ['support-agent'])

      get '/omniauth/ameide_oidc/callback'

      expect(response).to redirect_to('http://www.example.com/auth/ameide_oidc/callback')
      follow_redirect!
      expect(response).to redirect_to('http://www.example.com/app/login?error=ameide-oidc-access-denied')
    end
  end
end
