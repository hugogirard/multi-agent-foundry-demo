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
        // API base URL (no trailing slash) — overridden by /config endpoint at runtime
        apiBaseUrl: 'http://localhost:8000',

        // Application Insights instrumentation key — set by /config endpoint
        appInsightKey: '',

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

    /**
     * Fetch runtime configuration from the server and merge into Contoso.Config.
     * Must be called (and awaited) before using apiBaseUrl or appInsightKey.
     */
    window.Contoso.loadConfig = async function () {
        try {
            const resp = await fetch('/config');
            if (!resp.ok) throw new Error(`/config returned ${resp.status}`);
            const data = await resp.json();

            if (data.apiUrl) {
                window.Contoso.Config.apiBaseUrl = data.apiUrl;
            }
            if (data.appInsightKey) {
                window.Contoso.Config.appInsightKey = data.appInsightKey;
            }
        } catch (err) {
            console.warn('Failed to load /config, using defaults:', err);
        }
    };
})();
