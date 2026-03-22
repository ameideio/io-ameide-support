module Custom::DashboardController
  def index
    return redirect_to('/auth/ameide_oidc') if redirect_login_request_to_ameide_oidc?

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

  def redirect_login_request_to_ameide_oidc?
    request.get? &&
      request.format.html? &&
      request.path == '/app/login' &&
      params[:error].blank? &&
      params[:email].blank? &&
      params[:sso_auth_token].blank?
  end
end
