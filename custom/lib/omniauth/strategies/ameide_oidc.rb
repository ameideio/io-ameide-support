require 'json'
require 'net/http'
require 'omniauth-oauth2'

module Omniauth
end

module Omniauth::Strategies
end

class Omniauth::Strategies::AmeideOidc < OmniAuth::Strategies::OAuth2
  option :name, :ameide_oidc
  option :issuer_url, nil
  option :scope, 'openid email profile'
  option :client_options, {
    site: nil,
    authorize_url: nil,
    token_url: nil
  }

  uid do
    raw_info['sub'] || info['email']
  end

  info do
    {
      email: raw_info['email'],
      name: raw_info['name'] || [raw_info['given_name'], raw_info['family_name']].compact.join(' '),
      first_name: raw_info['given_name'],
      last_name: raw_info['family_name'],
      roles: AmeideOidcConfig.roles_from(raw_info)
    }.compact
  end

  extra do
    { raw_info: raw_info }
  end

  def client
    configure_client_options!
    super
  end

  def raw_info
    @raw_info ||= access_token.get(userinfo_endpoint).parsed
  end

  def callback_url
    options[:callback_url].presence || super
  end

  private

  def configure_client_options!
    options.client_options.site = issuer_url
    options.client_options.authorize_url = discovery_document.fetch('authorization_endpoint')
    options.client_options.token_url = discovery_document.fetch('token_endpoint')
  end

  def issuer_url
    @issuer_url ||= options[:issuer_url].to_s.chomp('/')
  end

  def discovery_document
    @discovery_document ||= begin
      uri = URI.parse("#{issuer_url}/.well-known/openid-configuration")
      response = Net::HTTP.get_response(uri)
      raise CallbackError.new(:invalid_credentials, 'issuer-discovery-failed') unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end
  end

  def userinfo_endpoint
    discovery_document.fetch('userinfo_endpoint')
  end
end

OmniAuth::Strategies.const_set(:AmeideOidc, Omniauth::Strategies::AmeideOidc) unless OmniAuth::Strategies.const_defined?(:AmeideOidc, false)
