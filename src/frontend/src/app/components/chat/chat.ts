import { Component, input, signal, afterRenderEffect, ViewChild, ElementRef } from "@angular/core";
import { Session } from "../../model/session";
import { Loading } from "../loading/loading";
import { MsalService } from "@azure/msal-angular";
import { MessageStore } from "../../stores/message.store";
import { RemarkModule } from "ngx-remark";

@Component({
    selector: 'chat-pane',
    standalone: true,
    styleUrl: './chat.css',
    templateUrl: './chat.html',
    imports: [Loading, RemarkModule]
})
export class Chat {

    session = input<Session>();
    isLoading = signal(false);
    isTyping = signal(false);
    showWelcome = signal(true);
    username: string | null = null;
    initial: string | null = null;
    userMessage = signal('');
    @ViewChild('chatInput') chatInput!: ElementRef<HTMLTextAreaElement>;

    readonly loadingTitle = 'Loading conversation';

    constructor(public messageStore: MessageStore, private authService: MsalService) {

        afterRenderEffect(() => {
            this.messageStore.messages();
            this.messageStore.streamingContent();
            const el = document.getElementById('chat-messages');
            if (el) el.scrollTop = el.scrollHeight;
        });


    }

    onNewChat() {
        this.isLoading.set(true);
        this.showWelcome.set(true);
        this.messageStore.newSession().subscribe({
            next: () => this.isLoading.set(false),
            error: () => this.isLoading.set(false)
        });
    }

    ngOnInit() {
        this.username = this.authService.instance.getActiveAccount()?.name ?? null;

        if (this.username) {
            const elements = this.username.split(' ');
            if (elements.length >= 2) {
                const firstLetter = elements[0][0];
                const lastLetter = elements[elements.length - 1][0];
                this.initial = `${firstLetter}${lastLetter}`;
            }
        }
    }

    onSuggestionClick(prompt: string) {
        this.showWelcome.set(false);
        this.userMessage.set(prompt);
        this.onSend();
    }

    onInput(event: Event) {
        const textarea = event.target as HTMLTextAreaElement;
        this.userMessage.set(textarea.value);
        textarea.style.height = 'auto';
        textarea.style.height = Math.min(textarea.scrollHeight, 150) + 'px';
    }

    onKeydown(event: KeyboardEvent) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.onSend();
        }
    }

    onSend() {
        const msg = this.userMessage().trim();
        if (!msg || this.messageStore.isStreaming()) return;

        this.showWelcome.set(false);
        this.messageStore.sendMessage(msg);
        this.userMessage.set('');

        if (this.chatInput?.nativeElement) {
            this.chatInput.nativeElement.style.height = 'auto';
            this.chatInput.nativeElement.focus();
        }
    }

    onOpenConsent() {
        this.messageStore.approveConsent();
    }

    onCancelConsent() {
        this.messageStore.cancelConsent();
    }

    formatTime(date: Date | undefined): string {
        if (!date) return '';
        return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }

    logout() {
        this.authService.logoutRedirect();
    }
}