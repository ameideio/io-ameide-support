require Rails.root.join('custom/lib/omniauth/strategies/ameide_oidc')

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :ameide_oidc,
           AmeideOidcConfig.client_id,
           AmeideOidcConfig.client_secret,
           issuer_url: AmeideOidcConfig.issuer_url,
           scope: AmeideOidcConfig.scope,
           callback_url: AmeideOidcConfig.callback_url
end
