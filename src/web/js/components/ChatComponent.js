/**
 * ChatComponent — main chat view with message list and input area.
 */
(function () {
    'use strict';

    class ChatComponent {
        /**
         * @param {Contoso.ChatService} chatService
         * @param {Contoso.AuthService} authService
         */
        constructor(chatService, authService) {
            this._chatService = chatService;
            this._authService = authService;
            this._el = null;
            this._messageList = null;
            this._input = null;
            this._sendBtn = null;
            this._welcome = null;
            this._isStreaming = false;
            /** @type {Map<number, Contoso.MessageComponent>} */
            this._messageComponents = new Map();
        }

        render() {
            this._el = document.createElement('div');
            this._el.className = 'chat-container';

            this._el.innerHTML = `
                <div class="chat-messages" id="chatMessages">
                    <div id="welcomeMount"></div>
                </div>
                <div class="chat-input-area" id="chatInputArea">
                    <div class="typing-indicator" id="typingIndicator" style="display:none">
                        <div class="typing-dot"></div>
                        <div class="typing-dot"></div>
                        <div class="typing-dot"></div>
                    </div>
                    <div class="input-row">
                        <textarea
                            id="chatInput"
                            class="chat-input"
                            placeholder="Ask me about flights, hotels, activities..."
                            rows="1"
                            disabled
                        ></textarea>
                        <button class="send-btn" id="sendBtn" disabled title="Send">
                            <span class="material-icons">send</span>
                        </button>
                    </div>
                    <div class="input-hint">
                        <span class="material-icons">info_outline</span>
                        Contoso Travel Agent — powered by AI. Responses may be inaccurate.
                    </div>
                </div>
            `;

            this._messageList = this._el.querySelector('#chatMessages');
            this._input = this._el.querySelector('#chatInput');
            this._sendBtn = this._el.querySelector('#sendBtn');

            this._showWelcome();
            this._bindEvents();

            this._authService.onAuthChange((signedIn) => {
                this._input.disabled = !signedIn;
                this._sendBtn.disabled = !signedIn;
                if (signedIn) {
                    this._input.placeholder = 'Ask me about flights, hotels, activities...';
                } else {
                    this._input.placeholder = 'Sign in to start chatting...';
                }
            });

            return this._el;
        }

        _showWelcome() {
            this._welcome = new Contoso.WelcomeComponent((prompt) => this._handleSend(prompt));
            const mount = this._el.querySelector('#welcomeMount');
            mount.appendChild(this._welcome.render());
        }

        _hideWelcome() {
            if (this._welcome) {
                this._welcome.destroy();
                this._welcome = null;
            }
        }

        _bindEvents() {
            this._sendBtn.addEventListener('click', () => this._handleSend());

            this._input.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    this._handleSend();
                }
            });

            // Auto-resize textarea
            this._input.addEventListener('input', () => {
                this._input.style.height = 'auto';
                this._input.style.height = Math.min(this._input.scrollHeight, 150) + 'px';
            });
        }

        async _handleSend(promptOverride) {
            const prompt = promptOverride || this._input.value.trim();
            if (!prompt || this._isStreaming || !this._authService.isSignedIn) return;

            this._hideWelcome();
            this._input.value = '';
            this._input.style.height = 'auto';
            this._setStreaming(true);

            // Render user message immediately
            const userMsg = Contoso.Message.createUserMessage(prompt);
            this._renderMessage(userMsg);

            // Prepare streaming assistant message
            const assistantMsg = Contoso.Message.createAssistantMessage('');
            const assistantComp = this._renderMessage(assistantMsg);

            this._showTyping();

            try {
                await this._chatService.sendMessage(prompt, {
                    onChunk: (text) => {
                        this._hideTyping();
                        assistantMsg.appendContent(text);
                        assistantComp.updateContent();
                        this._scrollToBottom();
                    },
                    onOAuthConsent: (consentMsg) => {
                        this._hideTyping();
                        this._renderMessage(consentMsg);
                        this._scrollToBottom();
                    },
                    onError: (errMsg) => {
                        this._hideTyping();
                        this._renderMessage(errMsg);
                        this._scrollToBottom();
                    },
                    onComplete: () => {
                        this._hideTyping();
                        this._setStreaming(false);
                        this._scrollToBottom();
                    }
                });
            } catch (err) {
                this._hideTyping();
                const errMsg = new Contoso.Message('system', 'Failed to send message: ' + err.message, 'error');
                this._renderMessage(errMsg);
                this._setStreaming(false);
            }
        }

        /**
         * @param {Contoso.Message} message
         * @returns {Contoso.MessageComponent}
         */
        _renderMessage(message) {
            const comp = new Contoso.MessageComponent(message);
            this._messageComponents.set(message.id, comp);

            const el = comp.render();
            // Insert before the typing indicator area
            this._messageList.appendChild(el);
            this._scrollToBottom();
            return comp;
        }

        _scrollToBottom() {
            requestAnimationFrame(() => {
                this._messageList.scrollTop = this._messageList.scrollHeight;
            });
        }

        _showTyping() {
            this._el.querySelector('#typingIndicator').style.display = 'flex';
        }

        _hideTyping() {
            this._el.querySelector('#typingIndicator').style.display = 'none';
        }

        _setStreaming(streaming) {
            this._isStreaming = streaming;
            this._input.disabled = streaming;
            this._sendBtn.disabled = streaming;
            if (!streaming) {
                this._input.focus();
            }
        }

        /** Reset chat for a new conversation. */
        reset() {
            this._messageComponents.clear();
            this._messageList.innerHTML = '<div id="welcomeMount"></div>';
            this._showWelcome();
            this._isStreaming = false;
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.ChatComponent = ChatComponent;
})();
