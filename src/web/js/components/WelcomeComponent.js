/**
 * WelcomeComponent — hero landing screen before first message.
 */
(function () {
    'use strict';

    class WelcomeComponent {
        /** @param {function(string):void} onSuggestionClick */
        constructor(onSuggestionClick) {
            this._onSuggestionClick = onSuggestionClick;
            this._el = null;
        }

        render() {
            this._el = document.createElement('div');
            this._el.className = 'welcome-container';
            this._el.innerHTML = `
                <div class="welcome-hero">
                    <div class="welcome-globe">
                        <span class="material-icons welcome-icon">travel_explore</span>
                    </div>
                    <h1 class="welcome-title">Where do you want to go?</h1>
                    <p class="welcome-subtitle">
                        I'm your AI travel agent. Ask me about flights, hotels, activities — or let me plan your entire trip!
                    </p>
                    <div class="welcome-suggestions">
                        <button class="suggestion-chip" data-prompt="Find me flights from Montreal to Paris">
                            <span class="material-icons">flight</span>
                            Flights to Paris
                        </button>
                    </div>
                </div>
                <div class="welcome-decoration">
                    <div class="floating-icon fi-1"><span class="material-icons">flight</span></div>
                    <div class="floating-icon fi-2"><span class="material-icons">luggage</span></div>
                    <div class="floating-icon fi-3"><span class="material-icons">beach_access</span></div>
                    <div class="floating-icon fi-4"><span class="material-icons">photo_camera</span></div>
                    <div class="floating-icon fi-5"><span class="material-icons">restaurant</span></div>
                </div>
            `;

            this._el.querySelectorAll('.suggestion-chip').forEach(chip => {
                chip.addEventListener('click', () => {
                    this._onSuggestionClick(chip.dataset.prompt);
                });
            });

            return this._el;
        }

        destroy() {
            if (this._el && this._el.parentNode) {
                this._el.parentNode.removeChild(this._el);
            }
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.WelcomeComponent = WelcomeComponent;
})();
