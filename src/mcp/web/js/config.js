/**
 * Configuration — API and MSAL settings.
 *
 * For local development, set demoMode = true to bypass Azure AD auth.
 * For production, fill in your Azure AD app registration values.
 */
(function () {
    'use strict';

    window.Contoso = window.Contoso || {};

    window.Contoso.Config = {
        // API base URL (no trailing slash)
        apiBaseUrl: 'http://localhost:8000',

        // Set to true to bypass MSAL auth (uses demoBearerToken instead)
        demoMode: false,

        // Bearer token for demo mode (paste a valid token here for local testing)
        demoBearerToken: '',

        // MSAL (Azure AD) settings — fill in with your app registration values
        msal: {
            clientId: '<YOUR_CLIENT_ID>',
            authority: 'https://login.microsoftonline.com/<YOUR_TENANT_ID>',
            redirectUri: window.location.origin + window.location.pathname,
            scopes: ['<YOUR_SCOPE_URI>/user_impersonation']
        }
    };
})();
