# Be sure to restart your server when you modify this file.
#
# OmniAuth/devise_token_auth's `redirect_callbacks` step stores the
# full `dta.omniauth.auth` hash in the session across an internal
# 307 from /omniauth/<provider>/callback to /auth/<provider>/callback.
# With `:cookie_store` (4 KB browser limit) an OIDC auth_hash that
# carries id_token + raw_info trivially overflows (~4.6 KB) and the
# whole sign-in fails with `ActionDispatch::Cookies::CookieOverflow`
# mid-redirect.
#
# Switch to `:cache_store`, which writes the session into Rails.cache.
# Production Rails.cache is the Redis cache store (Chatwoot wires it
# from REDIS_URL / CACHE_REDIS_URL via lib/redis), so this gives us a
# server-side, size-unbounded session store with no new infra.
Rails.application.config.session_store :cache_store, key: '_chatwoot_session', same_site: :lax, expire_after: 14.days
