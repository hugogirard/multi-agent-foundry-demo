/**
 * Conversation model — holds a session and its message history.
 */
(function () {
    'use strict';

    class Conversation {
        /** @param {Contoso.Session} session */
        constructor(session) {
            this.session = session;
            /** @type {Contoso.Message[]} */
            this.messages = [];
        }

        addMessage(message) {
            this.messages.push(message);
            return message;
        }

        getMessages() {
            return this.messages;
        }

        getLastAssistantMessage() {
            for (let i = this.messages.length - 1; i >= 0; i--) {
                if (this.messages[i].isAssistant) return this.messages[i];
            }
            return null;
        }

        updateSession(data) {
            this.session.update(data);
        }

        get messageCount() {
            return this.messages.length;
        }

        get isEmpty() {
            return this.messages.length === 0;
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.Conversation = Conversation;
})();
