/**
 * Message model — represents a single chat message.
 */
(function () {
    'use strict';

    let _idCounter = 0;

    class Message {
        /**
         * @param {'user'|'assistant'|'system'} role
         * @param {string} content
         * @param {'content'|'oauth_consent'|'error'} [type='content']
         */
        constructor(role, content, type = 'content') {
            this.id = ++_idCounter;
            this.role = role;
            this.content = content;
            this.type = type;
            this.timestamp = new Date();
        }

        get isUser() {
            return this.role === 'user';
        }

        get isAssistant() {
            return this.role === 'assistant';
        }

        get isError() {
            return this.type === 'error';
        }

        get isOAuthConsent() {
            return this.type === 'oauth_consent';
        }

        appendContent(text) {
            this.content += text;
        }

        /**
         * Create a Message from an SSE event payload.
         * @param {object} data — parsed JSON from the SSE stream
         * @returns {Message|null}
         */
        static fromSSEEvent(data) {
            switch (data.type) {
                case 'content':
                    return new Message('assistant', data.text, 'content');
                case 'oauth_consent':
                    return new Message('system', data.consentLink, 'oauth_consent');
                case 'error':
                    return new Message('system', data.text, 'error');
                default:
                    return null;
            }
        }

        static createUserMessage(text) {
            return new Message('user', text, 'content');
        }

        static createAssistantMessage(text = '') {
            return new Message('assistant', text, 'content');
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.Message = Message;
})();
