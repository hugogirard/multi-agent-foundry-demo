/**
 * AppShell — top-level layout assembling header, sidebar, and chat.
 */
(function () {
    'use strict';

    class AppShell {
        /**
         * @param {Contoso.AuthService} authService
         * @param {Contoso.ChatService} chatService
         */
        constructor(authService, chatService) {
            this._authService = authService;
            this._chatService = chatService;
            this._header = null;
            this._sidebar = null;
            this._chat = null;
        }

        mount(rootEl) {
            // Header
            this._header = new Contoso.HeaderComponent(this._authService);

            // Sidebar
            this._sidebar = new Contoso.SidebarComponent(
                this._authService,
                () => this._handleNewChat()
            );

            // Chat
            this._chat = new Contoso.ChatComponent(this._chatService, this._authService);

            // Overlay for sidebar on mobile
            const overlay = document.createElement('div');
            overlay.className = 'sidebar-overlay';
            overlay.addEventListener('click', () => this._sidebar.close());

            // Main layout
            const main = document.createElement('main');
            main.className = 'main-content';
            main.appendChild(this._chat.render());

            rootEl.innerHTML = '';
            rootEl.appendChild(this._header.render());
            rootEl.appendChild(this._sidebar.render());
            rootEl.appendChild(overlay);
            rootEl.appendChild(main);

            // Wire hamburger menu
            document.getElementById('menuToggle').addEventListener('click', () => {
                this._sidebar.toggle();
            });
        }

        async _handleNewChat() {
            try {
                await this._chatService.startNewChat();
                this._chat.reset();
            } catch (err) {
                console.error('Failed to start new chat:', err);
            }
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.AppShell = AppShell;
})();
