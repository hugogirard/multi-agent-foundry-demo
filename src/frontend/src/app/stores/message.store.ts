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
        lastSessionInfo: null as any
    });

    readonly messages = this.state.messages;
    readonly streamingContent = this.state.streamingContent;
    readonly isStreaming = this.state.isStreaming;
    readonly isStreamingError = this.state.isStreamingError;
    readonly lastSessionInfo = this.state.lastSessionInfo;

    newSession(): Observable<true> {

        patchState(this.state, {
            messages: [],
            streamingContent: '',
            isStreaming: false,
            lastSessionInfo: null
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
            isStreaming: true
        }));

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
                        patchState(this.state, { lastSessionInfo: obj });
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
            isStreamingError: false
        }));
    }

}