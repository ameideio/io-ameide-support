class SsoTokenExchangeController < ApplicationController
  # The SSO token is delivered to the SPA through an HttpOnly cookie set by
  # `DeviseOverrides::OmniauthCallbacksController#sign_in_user`. The SPA reads
  # it through this same-origin endpoint, then forwards it to `/auth/sign_in`.
  # The cookie is cleared on read so the token cannot be replayed from another tab.
  def create
    token = cookies[:sso_auth_token]
    cookies.delete(:sso_auth_token, path: '/app/login')

    return head :no_content if token.blank?

    render json: { sso_auth_token: token }
  end
end
