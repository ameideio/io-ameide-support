<script>
// utils and composables
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';

// components
import Spinner from 'shared/components/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'ameide-oidc-authentication-failed': 'LOGIN.API.UNAUTH',
  'ameide-oidc-access-denied': 'LOGIN.API.UNAUTH',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';
const SUPPORT_LOGIN_COPY = {
  heading: 'Continue to support',
  subtitle: 'Authenticate with Ameide identity.',
  redirecting: 'Redirecting to Ameide sign-in.',
  completing: 'Completing sign-in.',
  retryBody: 'Ameide sign-in did not complete. Retry to continue.',
  retryLabel: 'Continue with Ameide',
};

export default {
  components: {
    Spinner,
    NextButton,
    MfaVerification,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  data() {
    return {
      loginApi: {
        message: '',
        showLoading: false,
        hasErrored: false,
      },
      mfaRequired: false,
      mfaToken: null,
      resolvedSsoAuthToken: '',
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    effectiveSsoAuthToken() {
      return this.ssoAuthToken || this.resolvedSsoAuthToken;
    },
    redirectingToOidc() {
      return !this.effectiveSsoAuthToken && !this.authError && !this.email;
    },
    isCompletingLogin() {
      return Boolean(this.effectiveSsoAuthToken);
    },
    supportLoginCopy() {
      return SUPPORT_LOGIN_COPY;
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    } else if (this.email && !this.authError) {
      // SSO callback redirected here with the token stored in an HttpOnly cookie.
      // Exchange the cookie for the token before submitting.
      this.exchangeCookieForSsoToken();
    } else if (!this.authError) {
      window.location = '/auth/ameide_oidc';
      return;
    }
    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      // Use a method to get the translated text to avoid dynamic key warning
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      // wait for idle state
      this.requestIdleCallbackPolyfill(() => {
        // Remove the error query param from the url
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  methods: {
    getTranslatedMessage(key) {
      // Avoid dynamic key warning by handling each case explicitly
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    // TODO: Remove this when Safari gets wider support
    // Ref: https://caniuse.com/requestidlecallback
    //
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        // Fallback for safari
        // Using a delay of 0 allows the callback to be executed asynchronously
        // in the next available event loop iteration, similar to requestIdleCallback
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      // Detects impersonation mode via URL and sets a session flag to prevent user settings changes during impersonation.
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
      }
    },
    async exchangeCookieForSsoToken() {
      try {
        const response = await fetch('/auth/sso/exchange', {
          method: 'POST',
          credentials: 'same-origin',
        });
        if (!response.ok || response.status === 204) {
          window.location = '/auth/ameide_oidc';
          return;
        }
        const data = await response.json();
        if (data?.sso_auth_token) {
          this.resolvedSsoAuthToken = data.sso_auth_token;
          this.submitLogin();
        } else {
          window.location = '/auth/ameide_oidc';
        }
      } catch (error) {
        window.location = '/auth/ameide_oidc';
      }
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email ? decodeURIComponent(this.email) : '',
        password: '',
        sso_auth_token: this.effectiveSsoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
      };

      login(credentials)
        .then(result => {
          // Check if MFA is required
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }

          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          if (this.email) {
            window.location = '/app/login';
          }
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    handleMfaVerified() {
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      this.mfaRequired = false;
      this.mfaToken = null;
    },
  },
};
</script>

<template>
  <main
    class="flex flex-col w-full min-h-screen py-20 bg-n-brand/5 dark:bg-n-background sm:px-6 lg:px-8"
  >
    <section class="max-w-5xl mx-auto">
      <img
        :src="globalConfig.logo"
        :alt="globalConfig.installationName"
        class="block w-auto h-8 mx-auto dark:hidden"
      />
      <img
        v-if="globalConfig.logoDark"
        :src="globalConfig.logoDark"
        :alt="globalConfig.installationName"
        class="hidden w-auto h-8 mx-auto dark:block"
      />
      <h2 class="mt-6 text-3xl font-medium text-center text-n-slate-12">
        {{ supportLoginCopy.heading }}
      </h2>
      <p class="mt-3 text-sm text-center text-n-slate-11">
        {{ supportLoginCopy.subtitle }}
      </p>
    </section>

    <section v-if="mfaRequired" class="mt-11">
      <MfaVerification
        :mfa-token="mfaToken"
        @verified="handleMfaVerified"
        @cancel="handleMfaCancel"
      />
    </section>

    <section
      v-else
      class="bg-white shadow sm:mx-auto mt-11 sm:w-full sm:max-w-lg dark:bg-n-solid-2 p-11 sm:shadow-lg sm:rounded-lg"
      :class="{ 'animate-wiggle': loginApi.hasErrored }"
    >
      <div class="flex flex-col items-center justify-center gap-4 py-6">
        <Spinner
          v-if="redirectingToOidc || isCompletingLogin || loginApi.showLoading"
          color-scheme="primary"
          size=""
        />
        <p v-if="redirectingToOidc" class="text-sm text-center text-n-slate-11">
          {{ supportLoginCopy.redirecting }}
        </p>
        <p
          v-else-if="isCompletingLogin || loginApi.showLoading"
          class="text-sm text-center text-n-slate-11"
        >
          {{ supportLoginCopy.completing }}
        </p>
        <template v-else>
          <p class="text-sm text-center text-n-slate-11">
            {{ supportLoginCopy.retryBody }}
          </p>
          <NextButton
            lg
            class="w-full"
            :label="supportLoginCopy.retryLabel"
            @click="window.location = '/auth/ameide_oidc'"
          />
        </template>
      </div>
    </section>
  </main>
</template>
