class OmniauthPassthruController < ApplicationController
  ALLOWED_SEC_FETCH_SITES = %w[same-origin same-site none].freeze

  before_action :reject_cross_site_requests, only: [:show]

  def show
    render :show, layout: false
  end

  private

  def reject_cross_site_requests
    site = request.headers['Sec-Fetch-Site']
    # Allow when header is absent (legacy browsers / non-fetch navigations) and when it asserts a non-cross-site origin.
    return if site.blank? || ALLOWED_SEC_FETCH_SITES.include?(site)

    head :forbidden
  end
end
