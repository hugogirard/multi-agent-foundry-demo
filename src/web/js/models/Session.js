/**
 * Session model — holds Foundry session identifiers.
 */
(function () {
    'use strict';

    class Session {
        /**
         * @param {string} sessionId
         * @param {string|null} [serviceSessionId=null]
         */
        constructor(sessionId, serviceSessionId = null) {
            this.sessionId = sessionId;
            this.serviceSessionId = serviceSessionId;
        }

        /** Serialize for API request payload. */
        toPayload() {
            const payload = { sessionId: this.sessionId };
            if (this.serviceSessionId) {
                payload.serviceSessionId = this.serviceSessionId;
            }
            return payload;
        }

        /** Update from an SSE session_info event. */
        update(data) {
            if (data.sessionId) this.sessionId = data.sessionId;
            if (data.serviceSessionId) this.serviceSessionId = data.serviceSessionId;
        }

        static fromResponse(data) {
            return new Session(data.sessionId, data.serviceSessionId || null);
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.Session = Session;
})();
