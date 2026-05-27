/**
 * ChatService — orchestrates session creation and message sending.
 */
(function () {
    'use strict';

    class ChatService {
        /**
         * @param {Contoso.AuthService} authService
         * @param {Contoso.SessionRepository} sessionRepository
         * @param {Contoso.ChatRepository} chatRepository
         */
        constructor(authService, sessionRepository, chatRepository) {
            this._authService = authService;
            this._sessionRepo = sessionRepository;
            this._chatRepo = chatRepository;
            /** @type {Contoso.Conversation|null} */
            this.conversation = null;
        }

        /**
         * Start a fresh chat session.
         * @returns {Promise<Contoso.Conversation>}
         */
        async startNewChat() {
            const token = await this._authService.getAccessToken();
            const session = await this._sessionRepo.createSession(token);
            this.conversation = new Contoso.Conversation(session);
            return this.conversation;
        }

        /**
         * Send a user message and stream the assistant's reply.
         * @param {string} prompt
         * @param {object} callbacks
         * @param {function(string):void} callbacks.onChunk
         * @param {function(Contoso.Message):void} callbacks.onOAuthConsent
         * @param {function(Contoso.Message):void} callbacks.onError
         * @param {function():void} callbacks.onComplete
         * @returns {Promise<void>}
         */
        async sendMessage(prompt, callbacks) {
            if (!this.conversation) {
                await this.startNewChat();
            }

            // Add user message to conversation
            const userMsg = Contoso.Message.createUserMessage(prompt);
            this.conversation.addMessage(userMsg);

            // Prepare assistant message (will be built up incrementally)
            const assistantMsg = Contoso.Message.createAssistantMessage('');
            this.conversation.addMessage(assistantMsg);

            const token = await this._authService.getAccessToken();

            await this._chatRepo.sendMessage(
                prompt,
                this.conversation.session,
                token,
                {
                    onChunk: (text) => {
                        assistantMsg.appendContent(text);
                        callbacks.onChunk(text);
                    },
                    onSessionUpdate: (data) => {
                        this.conversation.updateSession(data);
                    },
                    onOAuthConsent: (link) => {
                        const consentMsg = new Contoso.Message('system', link, 'oauth_consent');
                        this.conversation.addMessage(consentMsg);
                        if (callbacks.onOAuthConsent) callbacks.onOAuthConsent(consentMsg);
                    },
                    onError: (text) => {
                        const errMsg = new Contoso.Message('system', text, 'error');
                        this.conversation.addMessage(errMsg);
                        if (callbacks.onError) callbacks.onError(errMsg);
                    },
                    onComplete: () => {
                        if (callbacks.onComplete) callbacks.onComplete();
                    }
                }
            );
        }

        get hasConversation() {
            return this.conversation !== null && !this.conversation.isEmpty;
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.ChatService = ChatService;
})();
