/**
 * HeaderComponent — top navigation bar.
 */
(function () {
    'use strict';

    class HeaderComponent {
        /** @param {Contoso.AuthService} authService */
        constructor(authService) {
            this._authService = authService;
            this._onNewChat = null;
            this._el = null;
        }

        render() {
            this._el = document.createElement('nav');
            this._el.className = 'contoso-header';
            this._el.innerHTML = `
                <div class="header-inner">
                    <div class="header-left">
                        <div class="brand">
                            <span class="material-icons brand-icon">flight_takeoff</span>
                            <span class="brand-text">Contoso Travel</span>
                        </div>
                    </div>
                    <div class="header-right">
                        <button class="btn-new-chat" id="btnNewChat" disabled title="New Chat">
                            <span class="material-icons">add_comment</span>
                            <span class="btn-new-chat-text">New Chat</span>
                        </button>
                        <div class="user-info" id="userInfo" style="display:none">
                            <span class="material-icons user-avatar">account_circle</span>
                            <span class="user-name" id="userName"></span>
                        </div>
                        <button class="btn-auth" id="btnAuth">
                            <span class="material-icons">login</span>
                            <span class="btn-auth-text">Sign In</span>
                        </button>
                    </div>
                </div>
            `;

            this._bindEvents();
            this._authService.onAuthChange((signedIn, user) => this._updateAuthUI(signedIn, user));
            this._authService.onAuthChange((signedIn) => {
                this._el.querySelector('#btnNewChat').disabled = !signedIn;
            });

            return this._el;
        }

        /** @param {function():void} cb */
        set onNewChat(cb) {
            this._onNewChat = cb;
        }

        _bindEvents() {
            this._el.querySelector('#btnNewChat').addEventListener('click', () => {
                if (this._onNewChat) this._onNewChat();
            });

            this._el.querySelector('#btnAuth').addEventListener('click', async () => {
                if (this._authService.isSignedIn) {
                    await this._authService.signOut();
                } else {
                    try {
                        await this._authService.signIn();
                    } catch (err) {
                        console.error('Sign-in error:', err);
                    }
                }
            });
        }

        _updateAuthUI(signedIn, user) {
            const userInfo = this._el.querySelector('#userInfo');
            const userName = this._el.querySelector('#userName');
            const btnAuth = this._el.querySelector('#btnAuth');

            if (signedIn && user) {
                userInfo.style.display = 'flex';
                userName.textContent = user.name;
                btnAuth.innerHTML = '<span class="material-icons">logout</span><span class="btn-auth-text">Sign Out</span>';
            } else {
                userInfo.style.display = 'none';
                userName.textContent = '';
                btnAuth.innerHTML = '<span class="material-icons">login</span><span class="btn-auth-text">Sign In</span>';
            }
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.HeaderComponent = HeaderComponent;
})();
