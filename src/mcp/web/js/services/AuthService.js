/**
 * AuthService — wraps MSAL.js for Azure AD authentication.
 */
(function () {
    'use strict';

    class AuthService {
        constructor(config) {
            this._config = config;
            this._msalInstance = null;
            this._account = null;
            this._onAuthChangeCallbacks = [];
        }

        async initialize() {
            if (this._config.demoMode) {
                this._account = { name: 'Demo User', username: 'demo@contoso.com' };
                this._notifyAuthChange();
                return;
            }

            const msalConfig = {
                auth: {
                    clientId: this._config.msal.clientId,
                    authority: this._config.msal.authority,
                    redirectUri: this._config.msal.redirectUri
                },
                cache: {
                    cacheLocation: 'sessionStorage',
                    storeAuthStateInCookie: false
                }
            };

            this._msalInstance = new msal.PublicClientApplication(msalConfig);
            await this._msalInstance.initialize();

            // Handle redirect response (if returning from redirect flow)
            const response = await this._msalInstance.handleRedirectPromise();
            if (response) {
                this._account = response.account;
                this._notifyAuthChange();
            } else {
                const accounts = this._msalInstance.getAllAccounts();
                if (accounts.length > 0) {
                    this._account = accounts[0];
                    this._notifyAuthChange();
                }
            }
        }

        async signIn() {
            if (this._config.demoMode) {
                this._account = { name: 'Demo User', username: 'demo@contoso.com' };
                this._notifyAuthChange();
                return;
            }

            try {
                const response = await this._msalInstance.loginPopup({
                    scopes: this._config.msal.scopes
                });
                this._account = response.account;
                this._notifyAuthChange();
            } catch (err) {
                console.error('Sign-in failed:', err);
                throw err;
            }
        }

        async signOut() {
            if (this._config.demoMode) {
                this._account = null;
                this._notifyAuthChange();
                return;
            }

            await this._msalInstance.logoutPopup();
            this._account = null;
            this._notifyAuthChange();
        }

        async getAccessToken() {
            if (this._config.demoMode) {
                return this._config.demoBearerToken || 'demo-token';
            }

            if (!this._account) throw new Error('Not signed in');

            try {
                const response = await this._msalInstance.acquireTokenSilent({
                    scopes: this._config.msal.scopes,
                    account: this._account
                });
                return response.accessToken;
            } catch (err) {
                // Silent token acquisition failed, try popup
                const response = await this._msalInstance.acquireTokenPopup({
                    scopes: this._config.msal.scopes,
                    account: this._account
                });
                return response.accessToken;
            }
        }

        getUser() {
            if (!this._account) return null;
            return {
                name: this._account.name || 'User',
                username: this._account.username || ''
            };
        }

        get isSignedIn() {
            return this._account !== null;
        }

        onAuthChange(callback) {
            this._onAuthChangeCallbacks.push(callback);
        }

        _notifyAuthChange() {
            const signedIn = this.isSignedIn;
            const user = this.getUser();
            this._onAuthChangeCallbacks.forEach(cb => cb(signedIn, user));
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.AuthService = AuthService;
})();
