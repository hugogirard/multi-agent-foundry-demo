export interface Session {
    sessionId: string;
    serviceSessionId?: string | null;
    consentLink?: string | null;
}