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
  let createElementSpy;
  let appendChildSpy;

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
    appendChildSpy = vi.spyOn(document.body, 'appendChild');
    createElementSpy = vi.spyOn(document, 'createElement');
    document.head.innerHTML = `
      <meta name="csrf-token" content="csrf-token-value" />
    `;
  });

  afterEach(() => {
    createElementSpy?.mockRestore();
    appendChildSpy?.mockRestore();
    document.head.innerHTML = '';
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

  it('starts the oidc flow with a form post', () => {
    const submit = vi.fn();
    createElementSpy.mockImplementation(tagName => {
      const element = document.createElementNS(
        'http://www.w3.org/1999/xhtml',
        tagName
      );
      if (tagName === 'form') {
        element.submit = submit;
      }
      return element;
    });

    createWrapper({});

    expect(appendChildSpy).toHaveBeenCalled();
    expect(submit).toHaveBeenCalled();

    const form = appendChildSpy.mock.calls[0][0];
    expect(form.method).toBe('post');
    expect(form.action).toBe('http://localhost:3000/auth/ameide_oidc');
    expect(form.querySelector('input[name="authenticity_token"]').value).toBe(
      'csrf-token-value'
    );
  });
});
