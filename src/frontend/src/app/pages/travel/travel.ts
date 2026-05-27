import { Component, signal } from "@angular/core";
import { Chat } from "../../components/chat/chat";
import { Session } from "../../model/session";
import { Loading } from "../../components/loading/loading";
import { MessageStore } from "../../stores/message.store";

@Component({
    selector: 'travel',
    standalone: true,
    templateUrl: './travel.html',
    styleUrl: './travel.css',
    imports: [Chat, Loading]
})
export class TravelPage {

    selectedSession = signal<Session | undefined>(undefined);
    isLoading = signal(false);

    constructor(private messageStore: MessageStore) {
    }

    ngOnInit() {
        this.isLoading.set(true);
        this.messageStore.newSession().subscribe({
            next: () => {
                this.selectedSession.set(this.messageStore.lastSessionInfo());
                this.isLoading.set(false);
            },
            error: () => this.isLoading.set(false)
        });
    }
}