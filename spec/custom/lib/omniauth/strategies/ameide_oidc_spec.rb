require 'rails_helper'

RSpec.describe Omniauth::Strategies::AmeideOidc do
  it 'aliases the custom strategy into OmniAuth for provider lookup' do
    expect(OmniAuth::Strategies::AmeideOidc).to be(described_class)
  end

  describe 'configured provider options' do
    it 'forces prompt=login on the request phase to defeat silent IdP re-auth' do
      builder_args = []
      mock_builder = Object.new
      mock_builder.define_singleton_method(:provider) do |*args, **kwargs|
        builder_args << [args, kwargs]
      end

      with_modified_env AMEIDE_OIDC_PROMPT: 'login' do
        # Re-evaluate the initializer body against our mock builder so we can assert
        # the wired authorize_params without booting another middleware instance.
        mock_builder.instance_exec do
          provider_options = {
            issuer_url: AmeideOidcConfig.issuer_url,
            scope: AmeideOidcConfig.scope,
            callback_url: AmeideOidcConfig.callback_url
          }
          provider_options[:authorize_params] = { prompt: AmeideOidcConfig.prompt } if AmeideOidcConfig.prompt.present?

          provider :ameide_oidc,
                   AmeideOidcConfig.client_id,
                   AmeideOidcConfig.client_secret,
                   **provider_options
        end
      end

      _args, kwargs = builder_args.first
      expect(kwargs[:authorize_params]).to eq(prompt: 'login')
    end

    it 'omits authorize_params entirely when prompt is disabled' do
      builder_args = []
      mock_builder = Object.new
      mock_builder.define_singleton_method(:provider) do |*args, **kwargs|
        builder_args << [args, kwargs]
      end

      with_modified_env AMEIDE_OIDC_PROMPT: 'false' do
        mock_builder.instance_exec do
          provider_options = {
            issuer_url: AmeideOidcConfig.issuer_url,
            scope: AmeideOidcConfig.scope,
            callback_url: AmeideOidcConfig.callback_url
          }
          provider_options[:authorize_params] = { prompt: AmeideOidcConfig.prompt } if AmeideOidcConfig.prompt.present?

          provider :ameide_oidc,
                   AmeideOidcConfig.client_id,
                   AmeideOidcConfig.client_secret,
                   **provider_options
        end
      end

      _args, kwargs = builder_args.first
      expect(kwargs).not_to have_key(:authorize_params)
    end
  end
end
