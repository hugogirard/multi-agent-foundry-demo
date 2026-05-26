/**
 * ChatRepository — handles streaming conversation with the API via SSE over POST.
 */
(function () {
    'use strict';

    class ChatRepository {
        /** @param {string} apiBaseUrl */
        constructor(apiBaseUrl) {
            this.apiBaseUrl = apiBaseUrl;
        }

        /**
         * Send a message and stream the response.
         * @param {string} prompt
         * @param {Contoso.Session} session
         * @param {string} accessToken
         * @param {object} callbacks
         * @param {function(string):void} callbacks.onChunk — called with each text chunk
         * @param {function(object):void} callbacks.onSessionUpdate — called with session_info data
         * @param {function(string):void} callbacks.onOAuthConsent — called with consent link
         * @param {function(string):void} callbacks.onError — called on error
         * @param {function():void} callbacks.onComplete — called when stream ends
         */
        async sendMessage(prompt, session, accessToken, callbacks) {
            const body = {
                prompt: prompt,
                answer: null,
                sessionInfo: session.toPayload()
            };

            let response;
            try {
                response = await fetch(`${this.apiBaseUrl}/api/conversation/`, {
                    method: 'POST',
                    headers: {
                        'Authorization': `Bearer ${accessToken}`,
                        'Content-Type': 'application/json',
                        'Accept': 'text/event-stream'
                    },
                    body: JSON.stringify(body)
                });
            } catch (err) {
                callbacks.onError('Network error: Unable to reach the server.');
                callbacks.onComplete();
                return;
            }

            if (!response.ok) {
                callbacks.onError(`Server error: ${response.status} ${response.statusText}`);
                callbacks.onComplete();
                return;
            }

            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let buffer = '';

            try {
                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;

                    buffer += decoder.decode(value, { stream: true });
                    const lines = buffer.split('\n');
                    buffer = lines.pop(); // keep incomplete line in buffer

                    for (const line of lines) {
                        const trimmed = line.trim();
                        if (!trimmed || !trimmed.startsWith('data:')) continue;

                        const jsonStr = trimmed.slice(5).trim();
                        if (!jsonStr) continue;

                        let event;
                        try {
                            event = JSON.parse(jsonStr);
                        } catch {
                            continue;
                        }

                        this._dispatchEvent(event, callbacks);
                    }
                }

                // Process any remaining buffer
                if (buffer.trim().startsWith('data:')) {
                    const jsonStr = buffer.trim().slice(5).trim();
                    if (jsonStr) {
                        try {
                            const event = JSON.parse(jsonStr);
                            this._dispatchEvent(event, callbacks);
                        } catch { /* ignore */ }
                    }
                }
            } catch (err) {
                callbacks.onError('Stream interrupted: ' + err.message);
            } finally {
                callbacks.onComplete();
            }
        }

        _dispatchEvent(event, callbacks) {
            switch (event.type) {
                case 'content':
                    callbacks.onChunk(event.text || '');
                    break;
                case 'session_info':
                    callbacks.onSessionUpdate(event);
                    break;
                case 'oauth_consent':
                    callbacks.onOAuthConsent(event.consentLink || '');
                    break;
                case 'error':
                    callbacks.onError(event.text || 'Unknown error');
                    break;
            }
        }
    }

    window.Contoso = window.Contoso || {};
    window.Contoso.ChatRepository = ChatRepository;
})();
