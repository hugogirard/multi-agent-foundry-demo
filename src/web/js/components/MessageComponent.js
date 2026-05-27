/**
 * MessageComponent — renders a single chat message bubble.
 */
(function () {
    'use strict';

    class MessageComponent {
        /** @param {Contoso.Message} message */
        constructor(message) {
            this.message = message;
            this._el = null;
            this._contentEl = null;
        }

        render() {
            this._el = document.createElement('div');
            this._el.className = `message message-${this.message.role}`;
            if (this.message.isError) this._el.classList.add('message-error');
            if (this.message.isOAuthConsent) this._el.classList.add('message-consent');

            const avatar = this.message.isUser
                ? '<span class="material-icons msg-avatar">person</span>'
                : '<span class="material-icons msg-avatar">smart_toy</span>';

            const label = this.message.isUser ? 'You' : 'Contoso Travel';

            this._el.innerHTML = `
                <div class="msg-avatar-wrap">${avatar}</div>
                <div class="msg-body">
                    <div class="msg-header">
                        <span class="msg-sender">${label}</span>
                        <span class="msg-time">${this._formatTime()}</span>
                    </div>
                    <div class="msg-content"></div>
                </div>
            `;

            this._contentEl = this._el.querySelector('.msg-content');
            this._renderContent();

            return this._el;
        }

        /** Update content (used during streaming). */
        updateContent() {
            this._renderContent();
        }

        _renderContent() {
            if (!this._contentEl) return;

            if (this.message.isOAuthConsent) {
                this._contentEl.innerHTML = `
                    <div class="consent-card">
                        <span class="material-icons consent-icon">verified_user</span>
                        <p>Authorization required to proceed.</p>
                        <a href="${this._escapeHtml(this.message.content)}" target="_blank" rel="noopener" class="consent-link">
                            <span class="material-icons">open_in_new</span> Grant Access
                        </a>
                    </div>
                `;
                return;
            }

            if (this.message.isError) {
                this._contentEl.innerHTML = `
                    <div class="error-card">
                        <span class="material-icons">error_outline</span>
                        <span>${this._escapeHtml(this.message.content)}</span>
                    </div>
                `;
                return;
            }

            if (this.message.isUser) {
                this._contentEl.textContent = this.message.content;
            } else {
                // Render markdown for assistant messages
                if (typeof marked !== 'undefined' && typeof marked.parse === 'function') {
                    this._contentEl.innerHTML = marked.parse(this.message.content || '', { breaks: true });
                } else {
                    this._contentEl.textContent = this.message.content;
                }
            }
        }

        _formatTime() {
            const d = this.message.timestamp;
            return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
        }

        _escapeHtml(str) {
            const div = document.createElement('div');
            div.textContent = str;
            return div.innerHTML;
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.MessageComponent = MessageComponent;
})();
