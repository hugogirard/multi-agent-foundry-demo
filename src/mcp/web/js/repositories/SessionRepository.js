/**
 * SessionRepository — API calls for session management.
 */
(function () {
    'use strict';

    class SessionRepository {
        /** @param {string} apiBaseUrl */
        constructor(apiBaseUrl) {
            this.apiBaseUrl = apiBaseUrl;
        }

        /**
         * Create a new chat session.
         * @param {string} accessToken — Bearer token
         * @returns {Promise<Contoso.Session>}
         */
        async createSession(accessToken) {
            const response = await fetch(`${this.apiBaseUrl}/api/session/new`, {
                method: 'GET',
                headers: {
                    'Authorization': `Bearer ${accessToken}`
                }
            });

            if (!response.ok) {
                throw new Error(`Failed to create session: ${response.status} ${response.statusText}`);
            }

            const data = await response.json();
            return Contoso.Session.fromResponse(data);
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.SessionRepository = SessionRepository;
})();
