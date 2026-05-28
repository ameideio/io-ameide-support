# OmniAuth configuration
# Sets the full host URL for callbacks and proper redirect handling
OmniAuth.config.full_host = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')

Rails.application.config.middleware.use OmniAuth::Builder do
  google_enabled = ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_GOOGLE_OAUTH_LOGIN', 'false'))

  if google_enabled
    provider :google_oauth2, ENV.fetch('GOOGLE_OAUTH_CLIENT_ID'), ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET')
  end
end
