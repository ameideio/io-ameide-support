require 'uri'

module AmeideOidcConfig
  module_function

  def account_name
    ENV.fetch('AMEIDE_CHATWOOT_ACCOUNT_NAME', 'Ameide')
  end

  def issuer_url
    ENV.fetch('AMEIDE_OIDC_ISSUER_URL', '').to_s.chomp('/')
  end

  def client_id
    ENV.fetch('AMEIDE_OIDC_CLIENT_ID', nil)
  end

  def client_secret
    ENV.fetch('AMEIDE_OIDC_CLIENT_SECRET', nil)
  end

  def callback_url
    ENV.fetch('AMEIDE_OIDC_CALLBACK_URL', nil)
  end

  def scope
    ENV.fetch('AMEIDE_OIDC_SCOPE', 'openid email profile')
  end

  def require_email_verified?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('AMEIDE_OIDC_REQUIRE_EMAIL_VERIFIED', 'true'))
  end

  def prompt
    value = ENV.fetch('AMEIDE_OIDC_PROMPT', 'login').to_s
    return nil if value.blank?
    return nil if %w[false 0 no off].include?(value.downcase)

    value
  end

  def default_role
    ENV.fetch('AMEIDE_OIDC_DEFAULT_ACCOUNT_ROLE', 'agent')
  end

  def allowed_email_domains
    csv_env('AMEIDE_OIDC_ALLOWED_EMAIL_DOMAINS')
  end

  def required_roles
    csv_env('AMEIDE_OIDC_REQUIRED_ROLES')
  end

  def admin_roles
    csv_env('AMEIDE_OIDC_ADMIN_ROLES')
  end

  def role_claim
    ENV.fetch('AMEIDE_OIDC_ROLE_CLAIM', 'realm_access.roles')
  end

  def post_logout_redirect_uri
    ENV.fetch('AMEIDE_OIDC_POST_LOGOUT_REDIRECT_URI', "#{ENV.fetch('FRONTEND_URL', '')}/app/login")
  end

  def end_session_endpoint
    endpoint = ENV.fetch('AMEIDE_OIDC_END_SESSION_ENDPOINT', nil)
    return endpoint if endpoint.present?
    return if issuer_url.blank?

    "#{issuer_url}/protocol/openid-connect/logout"
  end

  def jwks_uri
    endpoint = ENV.fetch('AMEIDE_OIDC_JWKS_URI', nil)
    return endpoint if endpoint.present?
    return if issuer_url.blank?

    "#{issuer_url}/protocol/openid-connect/certs"
  end

  def logout_redirect_link
    endpoint = end_session_endpoint
    return ENV.fetch('LOGOUT_REDIRECT_LINK', '/') if endpoint.blank?

    uri = URI.parse(endpoint)
    query = URI.decode_www_form(String(uri.query))
    query << ['client_id', client_id] if client_id.present?
    query << ['post_logout_redirect_uri', post_logout_redirect_uri] if post_logout_redirect_uri.present?
    uri.query = URI.encode_www_form(query)
    uri.to_s
  end

  def value_for_claim(claims, path)
    path.to_s.split('.').reduce(claims) do |value, key|
      break nil unless value.respond_to?(:[])

      value[key] || value[key.to_sym]
    end
  end

  def roles_from(claims)
    value = value_for_claim(claims, role_claim)
    Array.wrap(value).flat_map { |entry| entry.is_a?(Array) ? entry : [entry] }.compact.map(&:to_s)
  end

  def csv_env(key)
    ENV.fetch(key, '').split(',').map(&:strip).reject(&:empty?)
  end
end
