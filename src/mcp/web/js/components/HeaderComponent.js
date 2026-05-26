/**
 * HeaderComponent — top navigation bar.
 */
(function () {
    'use strict';

    class HeaderComponent {
        /** @param {Contoso.AuthService} authService */
        constructor(authService) {
            this._authService = authService;
            this._el = null;
        }

        render() {
            this._el = document.createElement('nav');
            this._el.className = 'contoso-header';
            this._el.innerHTML = `
                <div class="header-inner">
                    <div class="header-left">
                        <button class="menu-toggle" id="menuToggle" title="Menu">
                            <span class="material-icons">menu</span>
                        </button>
                        <div class="brand">
                            <span class="material-icons brand-icon">flight_takeoff</span>
                            <span class="brand-text">Contoso Travel</span>
                        </div>
                    </div>
                    <div class="header-right">
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

            return this._el;
        }

        _bindEvents() {
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
