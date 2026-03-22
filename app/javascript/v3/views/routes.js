import { frontendURL } from 'dashboard/helper/URLHelper';

import Login from './login/Index.vue';

export default [
  {
    path: frontendURL('login'),
    name: 'login',
    component: Login,
    props: route => ({
      config: route.query.config,
      email: route.query.email,
      ssoAuthToken: route.query.sso_auth_token,
      ssoAccountId: route.query.sso_account_id,
      ssoConversationId: route.query.sso_conversation_id,
      authError: route.query.error,
    }),
  },
];
