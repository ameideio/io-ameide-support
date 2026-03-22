require 'rails_helper'

RSpec.describe AmeideOidcConfig do
  describe '.roles_from' do
    it 'reads roles from realm_access.roles by default' do
      claims = { 'realm_access' => { 'roles' => %w[support-agent support-admin] } }

      expect(described_class.roles_from(claims)).to eq(%w[support-agent support-admin])
    end
  end

  describe '.logout_redirect_link' do
    it 'builds a keycloak logout url with the configured client and redirect uri' do
      with_modified_env \
        AMEIDE_OIDC_ISSUER_URL: 'https://sso.example.com/realms/ameide',
        AMEIDE_OIDC_CLIENT_ID: 'io-ameide-support',
        FRONTEND_URL: 'https://support.example.com' do
        expect(described_class.logout_redirect_link).to eq(
          'https://sso.example.com/realms/ameide/protocol/openid-connect/logout?' \
          'client_id=io-ameide-support&post_logout_redirect_uri=https%3A%2F%2Fsupport.example.com%2Fapp%2Flogin'
        )
      end
    end
  end
end
