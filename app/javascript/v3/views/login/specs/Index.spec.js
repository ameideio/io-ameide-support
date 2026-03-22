import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import LoginIndex from '../Index.vue';
import { login } from '../../../api/auth';

vi.mock('../../../api/auth', () => ({
  login: vi.fn(() => Promise.resolve({})),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

describe('Support login page', () => {
  const createWrapper = props =>
    mount(LoginIndex, {
      props,
      global: {
        plugins: [
          createStore({
            getters: {
              'globalConfig/get': () => ({
                logo: '/logo.svg',
                logoDark: '',
                installationName: 'Ameide Support',
              }),
            },
          }),
        ],
        mocks: {
          $t: key => key,
          $route: { query: {} },
          $router: { replace: vi.fn() },
        },
        stubs: {
          Spinner: true,
          NextButton: {
            template: '<button><slot /></button>',
            props: ['label'],
          },
          MfaVerification: true,
        },
      },
    });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('does not render the stock email and password form on auth errors', () => {
    const wrapper = createWrapper({ authError: 'ameide-oidc-access-denied' });

    expect(wrapper.text()).toContain('Ameide sign-in did not complete.');
    expect(wrapper.find('button').exists()).toBe(true);
    expect(wrapper.find('[data-testid="email_input"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="password_input"]').exists()).toBe(false);
  });

  it('submits the sso token flow when callback params are present', async () => {
    createWrapper({
      email: encodeURIComponent('agent@ameide.io'),
      ssoAuthToken: 'token',
    });

    await Promise.resolve();

    expect(login).toHaveBeenCalledWith({
      email: 'agent@ameide.io',
      password: '',
      sso_auth_token: 'token',
      ssoAccountId: '',
      ssoConversationId: '',
    });
  });
});
