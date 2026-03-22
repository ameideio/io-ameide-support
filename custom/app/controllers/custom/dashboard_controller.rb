module Custom::DashboardController
  private

  def app_config
    super.merge(
      LOGOUT_REDIRECT_LINK: '/auth/ameide_oidc/logout'
    )
  end

  def allowed_login_methods
    ['ameide_oidc']
  end

  def sensitive_path?
    false
  end
end
