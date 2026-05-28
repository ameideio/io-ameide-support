require Rails.root.join('custom/lib/omniauth/strategies/ameide_oidc')

AmeideOidcConfig.validate_required!

Rails.application.config.middleware.use OmniAuth::Builder do
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
