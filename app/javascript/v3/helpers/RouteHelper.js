import { frontendURL } from 'dashboard/helper/URLHelper';
import { clearBrowserSessionCookies } from 'dashboard/store/utils/api';
import { hasAuthCookie } from './AuthHelper';
import { DEFAULT_REDIRECT_URL } from 'dashboard/constants/globals';
import { replaceRouteWithReload } from './CommonHelper';

const validateSSOLoginParams = to => {
  const isLoginRoute = to.name === 'login';
  const { email, sso_auth_token: ssoAuthToken } = to.query || {};
  const hasValidSSOParams = email && ssoAuthToken;
  return isLoginRoute && hasValidSSOParams;
};

export const validateRouteAccess = (to, next) => {
  if (validateSSOLoginParams(to)) {
    clearBrowserSessionCookies();
    next();
    return;
  }

  // Redirect to dashboard if a cookie is present, the cookie
  // cleanup and token validation happens in the application pack.
  if (hasAuthCookie()) {
    replaceRouteWithReload(DEFAULT_REDIRECT_URL);
    return;
  }

  if (!to.name) {
    next(frontendURL('login'));
    return;
  }

  next();
};

export const isOnOnboardingView = route => {
  const { name = '' } = route || {};

  if (!name) {
    return false;
  }

  return name.includes('onboarding_');
};
