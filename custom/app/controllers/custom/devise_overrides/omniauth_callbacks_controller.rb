module Custom::DeviseOverrides::OmniauthCallbacksController
  def omniauth_success
    case auth_hash&.dig('provider')
    when 'ameide_oidc'
      handle_ameide_oidc_auth
    else
      super
    end
  end

  def omniauth_failure
    return super unless params[:provider] == 'ameide_oidc'

    redirect_to login_page_url(error: 'ameide-oidc-authentication-failed')
  end

  private

  def handle_ameide_oidc_auth
    @resource = AmeideOidcUserBuilder.new(auth_hash).perform
    return sign_in_user if @resource.persisted?

    redirect_to login_page_url(error: 'ameide-oidc-authentication-failed')
  rescue AmeideOidcUserBuilder::AuthenticationFailed
    redirect_to login_page_url(error: 'ameide-oidc-access-denied')
  end
end
