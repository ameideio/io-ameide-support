# Configure Rails.cache to use the same Redis as the rest of the app.
#
# Without this, `Rails.cache` defaults to `ActiveSupport::Cache::FileStore`
# (per-pod tmp/cache), which silently breaks anything that expects a
# shared cache. Specifically:
#   - session_store :cache_store (config/initializers/session_store.rb)
#     becomes a per-pod ephemeral file-backed store: sessions are lost on
#     pod restart and are sticky to a single replica, so multi-replica
#     web won't work for SSO.
#   - Rails.cache.fetch(...) calls inside Chatwoot won't share state
#     across web/worker/sidekiq pods.
#
# Use the same connection params Chatwoot already builds in
# config/initializers/01_redis.rb (Redis::Config.app), under a dedicated
# 'cache' namespace so we don't collide with the alfred / velma / thelma
# namespaces.
Rails.application.config.cache_store = :redis_cache_store, {
  url: ENV.fetch('REDIS_URL', 'redis://127.0.0.1:6379'),
  password: ENV.fetch('REDIS_PASSWORD', nil).presence,
  namespace: 'cache',
  reconnect_attempts: 2,
  connect_timeout: 1,
  read_timeout: 1,
  write_timeout: 1,
  error_handler: ->(method:, returning:, exception:) {
    Rails.logger.error("[Rails.cache] redis #{method} failed: #{exception.class}: #{exception.message}")
  }
}
