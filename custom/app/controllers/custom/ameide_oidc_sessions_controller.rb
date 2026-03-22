class Custom::AmeideOidcSessionsController < ActionController::Base
  def destroy
    redirect_to AmeideOidcConfig.logout_redirect_link, allow_other_host: true
  end
end
