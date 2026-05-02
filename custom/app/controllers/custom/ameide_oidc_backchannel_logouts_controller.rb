require 'jwt'
require 'json'
require 'net/http'
require 'uri'

# Handler for OpenID Connect Back-Channel Logout 1.0
# (https://openid.net/specs/openid-connect-backchannel-1_0.html).
#
# Keycloak POSTs a signed `logout_token` here when an SSO session ends. We
# verify the token against the issuer's JWKS, look up the matching Chatwoot
# user, and invalidate their active devise_token_auth client tokens so the
# session terminates without waiting for the Devise inactivity timeout.
#
# The Keycloak client `io-ameide-support` already declares
# `backchannel.logout.session.required: "true"` in
# `_shared/platform/platform-keycloak-realm.yaml`. Before this controller
# existed those POSTs hit a 404.
class Custom::AmeideOidcBackchannelLogoutsController < ApplicationController
  # Cache the JWKS for a few minutes so we are not refetching on every
  # incoming logout. Key rotation is rare and Keycloak signs a few minutes
  # ahead of the cutover, so this is safe.
  JWKS_CACHE_KEY = 'ameide_oidc:backchannel_logout:jwks'.freeze
  JWKS_CACHE_TTL = 5.minutes
  # Replay protection window per the spec (Section 2.4).
  JTI_CACHE_PREFIX = 'ameide_oidc:backchannel_logout:jti:'.freeze
  JTI_CACHE_TTL = 30.minutes
  BACKCHANNEL_LOGOUT_EVENT = 'http://schemas.openid.net/event/backchannel-logout'.freeze

  class LogoutTokenError < StandardError; end

  def create
    logout_token = params[:logout_token].to_s
    return render_error('missing logout_token') if logout_token.blank?

    claims = verify_and_decode(logout_token)
    validate_claims!(claims)

    user = User.find_by(provider: 'ameide_oidc', uid: claims['sub'])
    invalidate_sessions!(user) if user

    render json: {}, status: :ok
  rescue LogoutTokenError => e
    render_error(e.message)
  end

  private

  def render_error(message)
    Rails.logger.warn("[ameide_oidc] backchannel logout rejected: #{message}")
    render json: { error: 'invalid_request', error_description: message }, status: :bad_request
  end

  def verify_and_decode(logout_token)
    jwks_loader = ->(opts) { fetch_jwks(force: opts[:invalidate]) }
    payload, _header = JWT.decode(
      logout_token,
      nil,
      true,
      algorithms: %w[RS256 RS384 RS512 ES256 ES384 ES512],
      jwks: jwks_loader,
      verify_iat: true
    )
    payload
  rescue JWT::DecodeError => e
    raise LogoutTokenError, "invalid signature: #{e.message}"
  end

  def fetch_jwks(force: false)
    Rails.cache.delete(JWKS_CACHE_KEY) if force
    cached = Rails.cache.fetch(JWKS_CACHE_KEY, expires_in: JWKS_CACHE_TTL) do
      load_jwks_from_issuer
    end
    { keys: cached.fetch('keys', []) }
  end

  def load_jwks_from_issuer
    uri_str = AmeideOidcConfig.jwks_uri
    raise LogoutTokenError, 'jwks_uri not configured' if uri_str.blank?

    response = Net::HTTP.get_response(URI.parse(uri_str))
    raise LogoutTokenError, "jwks fetch failed: #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end

  def validate_claims!(claims)
    validate_issuer!(claims)
    validate_audience!(claims)
    validate_events!(claims)
    raise LogoutTokenError, 'logout_token must not contain a nonce claim' if claims.key?('nonce')
    raise LogoutTokenError, 'logout_token must contain sub or sid' if claims['sub'].blank? && claims['sid'].blank?

    enforce_jti_replay_guard!(claims['jti'])
  end

  def validate_issuer!(claims)
    expected = AmeideOidcConfig.issuer_url
    raise LogoutTokenError, 'issuer mismatch' if expected.blank? || claims['iss'].to_s.chomp('/') != expected
  end

  def validate_audience!(claims)
    expected = AmeideOidcConfig.client_id
    raise LogoutTokenError, 'audience mismatch' if expected.blank? || !audience_matches?(claims['aud'], expected)
  end

  def validate_events!(claims)
    events = claims['events']
    return if events.is_a?(Hash) && events.key?(BACKCHANNEL_LOGOUT_EVENT)

    raise LogoutTokenError, 'events claim missing backchannel-logout event'
  end

  def audience_matches?(claim_aud, expected)
    Array(claim_aud).map(&:to_s).include?(expected.to_s)
  end

  def enforce_jti_replay_guard!(jti)
    return if jti.blank?

    cache_key = "#{JTI_CACHE_PREFIX}#{jti}"
    raise LogoutTokenError, 'logout_token replay detected' if Rails.cache.read(cache_key)

    Rails.cache.write(cache_key, true, expires_in: JTI_CACHE_TTL)
  end

  def invalidate_sessions!(user)
    # devise_token_auth keeps active client tokens in the JSON `tokens` column
    # on `users`. Clearing it forces every browser tab/API client to re-auth
    # via the OIDC flow, which re-runs the role + email_verified check in the
    # user builder.
    user.update_columns(tokens: {}) # rubocop:disable Rails/SkipsModelValidations

    # Best-effort: also revoke the personal access_token (used for Chatwoot's
    # programmatic API) so an offboarded operator cannot keep automating.
    user.access_token&.regenerate_token
  rescue StandardError => e
    Rails.logger.error("[ameide_oidc] failed to invalidate sessions for user=#{user.id}: #{e.class}: #{e.message}")
  end
end
