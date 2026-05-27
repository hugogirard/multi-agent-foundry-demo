export enum Role {
    User = 'user',
    Assistant = 'assistant',
    System = 'system'
}

export type MessageType = 'content' | 'error';

let _idCounter = 0;

export class Message {
    id: number;
    role: Role;
    content: string;
    type: MessageType;
    timestamp: Date;

    constructor(role: Role, content: string, type: MessageType = 'content') {
        this.id = ++_idCounter;
        this.role = role;
        this.content = content;
        this.type = type;
        this.timestamp = new Date();
    }

    get isUser(): boolean {
        return this.role === Role.User;
    }

    get isAssistant(): boolean {
        return this.role === Role.Assistant;
    }

    get isError(): boolean {
        return this.type === 'error';
    }

    appendContent(text: string) {
        this.content += text;
    }

    static createUserMessage(text: string): Message {
        return new Message(Role.User, text, 'content');
    }

    static createAssistantMessage(text: string = ''): Message {
        return new Message(Role.Assistant, text, 'content');
    }

    static fromSSEEvent(data: { type: string; text?: string }): Message | null {
        switch (data.type) {
            case 'content':
                return new Message(Role.Assistant, data.text || '', 'content');
            case 'error':
                return new Message(Role.System, data.text || '', 'error');
            default:
                return null;
        }
    }
}