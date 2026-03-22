module Custom::DeviseOverrides::SessionsController
  include AmeideOidcAuthenticationHelper

  def create
    if ameide_oidc_user_attempting_password_auth?(params[:email], sso_auth_token: params[:sso_auth_token])
      render json: {
        success: false,
        message: 'Use Ameide SSO to sign in.',
        errors: ['Use Ameide SSO to sign in.']
      }, status: :unauthorized
      return
    end

    super
  end
end
