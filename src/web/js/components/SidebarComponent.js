/**
 * SidebarComponent — side navigation with new chat and branding.
 */
(function () {
    'use strict';

    class SidebarComponent {
        /**
         * @param {Contoso.AuthService} authService
         * @param {function():void} onNewChat
         */
        constructor(authService, onNewChat) {
            this._authService = authService;
            this._onNewChat = onNewChat;
            this._el = null;
            this._isOpen = false;
        }

        render() {
            this._el = document.createElement('aside');
            this._el.className = 'contoso-sidebar';
            this._el.innerHTML = `
                <div class="sidebar-content">
                    <button class="sidebar-new-chat" id="sidebarNewChat" disabled>
                        <span class="material-icons">add_comment</span>
                        New Chat
                    </button>
                    <div class="sidebar-divider"></div>
                    <div class="sidebar-section">
                        <span class="sidebar-section-title">Explore</span>
                        <div class="sidebar-item">
                            <span class="material-icons">flight</span>
                            <span>Flights</span>
                        </div>
                        <div class="sidebar-item">
                            <span class="material-icons">hotel</span>
                            <span>Hotels</span>
                        </div>
                        <div class="sidebar-item">
                            <span class="material-icons">local_activity</span>
                            <span>Activities</span>
                        </div>
                    </div>
                    <div class="sidebar-spacer"></div>
                    <div class="sidebar-footer">
                        <div class="sidebar-branding">
                            <span class="material-icons">public</span>
                            <div>
                                <div class="sidebar-brand-name">Contoso Travel</div>
                                <div class="sidebar-brand-tagline">Your AI travel agent</div>
                            </div>
                        </div>
                    </div>
                </div>
            `;

            this._bindEvents();
            this._authService.onAuthChange((signedIn) => {
                this._el.querySelector('#sidebarNewChat').disabled = !signedIn;
            });

            return this._el;
        }

        _bindEvents() {
            this._el.querySelector('#sidebarNewChat').addEventListener('click', () => {
                if (this._authService.isSignedIn) {
                    this._onNewChat();
                    this.close();
                }
            });
        }

        toggle() {
            this._isOpen = !this._isOpen;
            this._el.classList.toggle('open', this._isOpen);
            document.body.classList.toggle('sidebar-open', this._isOpen);
        }

        close() {
            this._isOpen = false;
            this._el.classList.remove('open');
            document.body.classList.remove('sidebar-open');
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.SidebarComponent = SidebarComponent;
})();
