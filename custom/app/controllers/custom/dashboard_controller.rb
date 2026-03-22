module Custom::DashboardController
  private

  def app_config
    return super unless AmeideOidcConfig.enabled?

    super.merge(
      ALLOWED_LOGIN_METHODS: ['ameide_oidc'],
      LOGOUT_REDIRECT_LINK: '/auth/ameide_oidc/logout'
    )
  end

  def allowed_login_methods
    return ['ameide_oidc'] if AmeideOidcConfig.enabled?

    super
  end
end
