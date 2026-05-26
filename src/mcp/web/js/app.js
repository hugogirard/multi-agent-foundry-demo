/**
 * App — bootstrap the Contoso Travel Agency SPA.
 */
(function () {
    'use strict';

    async function boot() {
        const config = Contoso.Config;

        // 1. Auth Service
        const authService = new Contoso.AuthService(config);

        // 2. Repositories
        const sessionRepo = new Contoso.SessionRepository(config.apiBaseUrl);
        const chatRepo = new Contoso.ChatRepository(config.apiBaseUrl);

        // 3. Chat Service
        const chatService = new Contoso.ChatService(authService, sessionRepo, chatRepo);

        // 4. Mount App Shell
        const shell = new Contoso.AppShell(authService, chatService);
        shell.mount(document.getElementById('app'));

        // 5. Initialize auth (loads cached sessions, handles redirects)
        try {
            await authService.initialize();
        } catch (err) {
            console.error('Auth initialization failed:', err);
        }
    }

    // Wait for DOM, then boot
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', boot);
    } else {
        boot();
    }
})();
