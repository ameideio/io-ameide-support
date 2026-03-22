module Custom::DashboardController
  def index
    super
  end

  private

  def app_config
    super.merge(
      LOGOUT_REDIRECT_LINK: '/auth/ameide_oidc/logout'
    )
  end

  def allowed_login_methods
    ['ameide_oidc']
  end
end
