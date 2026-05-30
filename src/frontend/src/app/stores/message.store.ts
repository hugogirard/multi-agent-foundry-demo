import { Injectable } from "@angular/core";
import { patchState, signalState } from "@ngrx/signals";
import { TravelService } from "../services/travel.service";
import { HttpEventType } from "@angular/common/http";
import { Message, Role } from "../model/message";
import { SessionService } from "../services/session.service";
import { map, Observable, tap } from "rxjs";


@Injectable({
    providedIn: 'root'
})
export class MessageStore {

    constructor(private travelService: TravelService, private sessionService: SessionService) { }

    private state = signalState({
        messages: [] as Message[],
        streamingContent: '',
        isStreaming: false,
        isStreamingError: false,
        lastSessionInfo: null as any,
        consentPending: false,
        consentLink: null as string | null,
        pendingPrompt: '',
        consentApproved: false
    });

    readonly messages = this.state.messages;
    readonly streamingContent = this.state.streamingContent;
    readonly isStreaming = this.state.isStreaming;
    readonly isStreamingError = this.state.isStreamingError;
    readonly lastSessionInfo = this.state.lastSessionInfo;
    readonly consentPending = this.state.consentPending;
    readonly consentLink = this.state.consentLink;

    private consentPollTimer: ReturnType<typeof setInterval> | null = null;

    newSession(): Observable<true> {

        patchState(this.state, {
            messages: [],
            streamingContent: '',
            isStreaming: false,
            lastSessionInfo: null,
            consentPending: false,
            consentLink: null,
            pendingPrompt: '',
            consentApproved: false
        });

        return this.sessionService.createNewSession().pipe(
            tap((session) => patchState(this.state, {
                lastSessionInfo: session
            })),
            map(() => true));

    }

    sendMessage(prompt: string) {
        patchState(this.state, (state) => ({
            messages: [...state.messages, Message.createUserMessage(prompt)],
            streamingContent: '',
            isStreaming: true,
            pendingPrompt: prompt
        }));

        this.travelService.askQuestion(prompt, this.state.lastSessionInfo()).subscribe({
            next: (event) => {
                if (event.type === HttpEventType.DownloadProgress) {
                    const rawData = (event as any).partialText;
                    this.parseStream(rawData);
                }
                if (event.type === HttpEventType.Response) {
                    if (this.state.consentPending()) {
                        // Don't finalize normally — waiting for consent
                        patchState(this.state, { isStreaming: false });
                    } else {
                        this.finalize();
                    }
                }
            },
            error: () => patchState(this.state, { isStreaming: false })
        });
    }

    approveConsent() {
        const link = this.state.consentLink();
        if (!link) return;

        const popup = window.open(link, 'mcpConsent', 'width=600,height=700,scrollbars=yes');

        if (!popup || popup.closed) {
            // Popup blocked — open in new tab as fallback
            window.open(link, '_blank');
        }

        this.consentPollTimer = setInterval(() => {
            if (popup && popup.closed) {
                this.clearConsentPoll();
                patchState(this.state, {
                    consentPending: false,
                    consentLink: null,
                    consentApproved: true
                });
                this.resendPendingMessage();
            }
        }, 500);
    }

    cancelConsent() {
        this.clearConsentPoll();
        patchState(this.state, {
            consentPending: false,
            consentLink: null,
            pendingPrompt: '',
            streamingContent: '',
            isStreaming: false,
            isStreamingError: false
        });
    }

    private resendPendingMessage() {
        const prompt = this.state.pendingPrompt();
        if (!prompt) return;

        patchState(this.state, {
            streamingContent: '',
            isStreaming: true
        });

        this.travelService.askQuestion(prompt, this.state.lastSessionInfo()).subscribe({
            next: (event) => {
                if (event.type === HttpEventType.DownloadProgress) {
                    const rawData = (event as any).partialText;
                    this.parseStream(rawData);
                }
                if (event.type === HttpEventType.Response) {
                    this.finalize();
                }
            },
            error: () => patchState(this.state, { isStreaming: false })
        });
    }

    private clearConsentPoll() {
        if (this.consentPollTimer) {
            clearInterval(this.consentPollTimer);
            this.consentPollTimer = null;
        }
    }

    private parseStream(raw: string) {
        try {
            const jsonStrings = raw
                .split(/(?<=\})\s*(?=\{)/)
                .filter(s => s.trim());

            let fulltext = '';
            let parsed = false;

            for (const jsonStr of jsonStrings) {
                try {
                    const obj = JSON.parse(jsonStr);
                    parsed = true;

                    if (obj.type === 'content') {
                        fulltext += obj.text;
                    } else if (obj.type === 'error') {
                        fulltext += obj.text;
                        patchState(this.state, { isStreamingError: true });
                    } else if (obj.type === 'session_info') {
                        patchState(this.state, {
                            lastSessionInfo: {
                                sessionId: obj.sessionId,
                                serviceSessionId: obj.serviceSessionId
                            }
                        });

                        if (obj.consentLink && !this.state.consentApproved()) {
                            patchState(this.state, {
                                consentPending: true,
                                consentLink: obj.consentLink
                            });
                        }
                    }
                } catch {
                    // Incomplete chunk, skip
                }
            }

            if (parsed) {
                patchState(this.state, { streamingContent: fulltext });
            }
        } catch {
            // Ignore parse errors from partial chunks
        }
    }

    private finalize() {
        const content = this.state.streamingContent();
        const isError = this.state.isStreamingError();
        const msg = new Message(Role.Assistant, content, isError ? 'error' : 'content');

        patchState(this.state, (state) => ({
            messages: [...state.messages, msg],
            streamingContent: '',
            isStreaming: false,
            isStreamingError: false,
            pendingPrompt: '',
            consentApproved: false
        }));
    }

}