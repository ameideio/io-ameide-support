require 'rails_helper'

RSpec.describe AmeideOidcUserBuilder do
  let(:account_name) { "Ameide OIDC #{SecureRandom.hex(4)}" }
  let(:user_email) { "agent-#{SecureRandom.hex(4)}@ameide.io" }
  let!(:account) { create(:account, name: account_name) }

  let(:auth_hash) do
    OmniAuth::AuthHash.new(
      provider: 'ameide_oidc',
      uid: 'oidc-user-1',
      info: {
        email: user_email,
        name: 'Ameide Agent',
        first_name: 'Ameide',
        last_name: 'Agent'
      },
      extra: {
        raw_info: {
          sub: 'oidc-user-1',
          email: user_email,
          email_verified: true,
          given_name: 'Ameide',
          family_name: 'Agent',
          realm_access: {
            roles: ['support-agent']
          }
        }
      }
    )
  end

  it 'creates a new ameide oidc user and adds them to the support account' do
    with_modified_env AMEIDE_OIDC_REQUIRED_ROLES: 'support-agent', AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name do
      user = described_class.new(auth_hash).perform

      expect(user.email).to eq(user_email)
      expect(user.provider).to eq('ameide_oidc')
      expect(user.accounts).to include(account)
      expect(user.account_users.find_by(account: account).role).to eq('agent')
    end
  end

  it 'maps configured admin roles to administrator' do
    with_modified_env(
      AMEIDE_OIDC_REQUIRED_ROLES: 'support-admin',
      AMEIDE_OIDC_ADMIN_ROLES: 'support-admin',
      AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name
    ) do
      admin_hash = auth_hash.deep_dup
      admin_hash['extra']['raw_info']['realm_access']['roles'] = ['support-admin']
      admin_hash['info']['roles'] = ['support-admin']

      user = described_class.new(admin_hash).perform

      expect(user.account_users.find_by(account: account).role).to eq('administrator')
    end
  end

  it 'rejects users outside the allowed email domains' do
    with_modified_env AMEIDE_OIDC_ALLOWED_EMAIL_DOMAINS: 'ameide.io', AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name do
      denied_hash = auth_hash.deep_dup
      denied_hash['info']['email'] = 'agent@example.com'
      denied_hash['extra']['raw_info']['email'] = 'agent@example.com'

      expect do
        described_class.new(denied_hash).perform
      end.to raise_error(AmeideOidcUserBuilder::AuthenticationFailed)
    end
  end

  describe 'email_verified enforcement' do
    it 'rejects unverified emails when AMEIDE_OIDC_REQUIRE_EMAIL_VERIFIED defaults to true' do
      with_modified_env AMEIDE_OIDC_REQUIRED_ROLES: 'support-agent', AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name do
        unverified = auth_hash.deep_dup
        unverified['extra']['raw_info']['email_verified'] = false

        expect do
          described_class.new(unverified).perform
        end.to raise_error(AmeideOidcUserBuilder::AuthenticationFailed)
      end
    end

    it 'rejects when email_verified claim is missing' do
      with_modified_env AMEIDE_OIDC_REQUIRED_ROLES: 'support-agent', AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name do
        missing = auth_hash.deep_dup
        missing['extra']['raw_info'].delete('email_verified')

        expect do
          described_class.new(missing).perform
        end.to raise_error(AmeideOidcUserBuilder::AuthenticationFailed)
      end
    end

    it 'accepts verified emails when AMEIDE_OIDC_REQUIRE_EMAIL_VERIFIED is true' do
      with_modified_env(
        AMEIDE_OIDC_REQUIRED_ROLES: 'support-agent',
        AMEIDE_OIDC_REQUIRE_EMAIL_VERIFIED: 'true',
        AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name
      ) do
        verified = auth_hash.deep_dup
        verified['extra']['raw_info']['email_verified'] = true

        user = described_class.new(verified).perform
        expect(user).to be_persisted
      end
    end

    it 'accepts unverified emails when AMEIDE_OIDC_REQUIRE_EMAIL_VERIFIED is false' do
      with_modified_env(
        AMEIDE_OIDC_REQUIRED_ROLES: 'support-agent',
        AMEIDE_OIDC_REQUIRE_EMAIL_VERIFIED: 'false',
        AMEIDE_CHATWOOT_ACCOUNT_NAME: account_name
      ) do
        unverified = auth_hash.deep_dup
        unverified['extra']['raw_info']['email_verified'] = false

        user = described_class.new(unverified).perform
        expect(user).to be_persisted
      end
    end
  end
end
