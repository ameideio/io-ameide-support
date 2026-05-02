require 'rails_helper'

RSpec.describe AmeideOidcConfig do
  describe '.roles_from' do
    it 'reads roles from realm_access.roles by default' do
      claims = { 'realm_access' => { 'roles' => %w[support-agent support-admin] } }

      expect(described_class.roles_from(claims)).to eq(%w[support-agent support-admin])
    end
  end

  describe '.post_logout_redirect_uri' do
    it 'defaults to the support login page when no override is provided' do
      with_modified_env FRONTEND_URL: 'https://support.example.com' do
        expect(described_class.post_logout_redirect_uri).to eq('https://support.example.com/app/login')
      end
    end
  end

  describe '.require_email_verified?' do
    it 'defaults to true' do
      with_modified_env AMEIDE_OIDC_REQUIRE_EMAIL_VERIFIED: nil do
        expect(described_class.require_email_verified?).to be(true)
      end
    end

    it 'is false when explicitly disabled' do
      with_modified_env AMEIDE_OIDC_REQUIRE_EMAIL_VERIFIED: 'false' do
        expect(described_class.require_email_verified?).to be(false)
      end
    end
  end

  describe '.prompt' do
    it 'defaults to "login" so an active IdP session never silently signs the user in' do
      with_modified_env AMEIDE_OIDC_PROMPT: nil do
        expect(described_class.prompt).to eq('login')
      end
    end

    it 'returns nil when set to a falsey value' do
      with_modified_env AMEIDE_OIDC_PROMPT: 'false' do
        expect(described_class.prompt).to be_nil
      end
    end

    it 'returns the configured value when explicitly set' do
      with_modified_env AMEIDE_OIDC_PROMPT: 'consent' do
        expect(described_class.prompt).to eq('consent')
      end
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
