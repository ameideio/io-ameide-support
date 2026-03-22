require 'rails_helper'

RSpec.describe DashboardController, type: :controller do
  describe '#allowed_login_methods' do
    it 'forces ameide oidc when the custom login is enabled' do
      with_modified_env ENABLE_AMEIDE_OIDC_LOGIN: 'true' do
        expect(controller.send(:allowed_login_methods)).to eq(['ameide_oidc'])
      end
    end
  end

  describe '#app_config' do
    before do
      allow(Chatwoot).to receive(:config).and_return({ version: 'test-version' })
      allow(VapidService).to receive(:public_key).and_return(nil)
      allow(GlobalConfigService).to receive(:load).and_return('')
      allow(ChatwootApp).to receive(:enterprise?).and_return(false)
    end

    it 'publishes the keycloak logout redirect when oidc is enabled' do
      with_modified_env \
        ENABLE_AMEIDE_OIDC_LOGIN: 'true',
        AMEIDE_OIDC_ISSUER_URL: 'https://sso.example.com/realms/ameide',
        AMEIDE_OIDC_CLIENT_ID: 'io-ameide-support',
        FRONTEND_URL: 'https://support.example.com' do
        config = controller.send(:app_config)

        expect(config[:ALLOWED_LOGIN_METHODS]).to eq(['ameide_oidc'])
        expect(config[:LOGOUT_REDIRECT_LINK]).to eq('/auth/ameide_oidc/logout')
      end
    end
  end
end
