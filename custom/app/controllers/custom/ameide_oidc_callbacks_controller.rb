class Custom::AmeideOidcCallbacksController < ApplicationController
  def success
    auth = request.env['omniauth.auth']
    return redirect_to_login(error: 'ameide-oidc-authentication-failed') unless auth&.dig('provider') == 'ameide_oidc'

    resource = AmeideOidcUserBuilder.new(auth).perform
    return redirect_to_login(error: 'ameide-oidc-authentication-failed') unless resource.persisted?

    resource.skip_confirmation! if resource.respond_to?(:skip_confirmation!)

    redirect_to_login(
      email: ERB::Util.url_encode(resource.email),
      sso_auth_token: resource.generate_sso_auth_token
    )
  rescue AmeideOidcUserBuilder::AuthenticationFailed
    redirect_to_login(error: 'ameide-oidc-access-denied')
  end

  def failure
    redirect_to_login(error: 'ameide-oidc-authentication-failed')
  end

  private

  def redirect_to_login(error: nil, email: nil, sso_auth_token: nil)
    frontend_url = ENV.fetch('FRONTEND_URL', nil)
    query = { email: email, sso_auth_token: sso_auth_token }.compact
    query[:error] = error if error.present?
    redirect_to "#{frontend_url}/app/login?#{query.to_query}"
  end
end
