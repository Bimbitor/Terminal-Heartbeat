import { kv } from "@vercel/kv";

export interface Message {
  id: string;
  text: string;
  createdAt: string;
}

export interface Greeting {
  id: string;
  text: string;
}

export interface Greetings {
  morning: Greeting[];
  afternoon: Greeting[];
  night: Greeting[];
}

const MESSAGES_KEY = "heartbeat:messages";
const GREETINGS_KEY = "heartbeat:greetings";

export async function getMessages(): Promise<Message[]> {
  return (await kv.get<Message[]>(MESSAGES_KEY)) ?? [];
}

export async function setMessages(messages: Message[]): Promise<void> {
  await kv.set(MESSAGES_KEY, messages);
}

export async function getGreetings(): Promise<Greetings> {
  return (
    (await kv.get<Greetings>(GREETINGS_KEY)) ?? {
      morning: [],
      afternoon: [],
      night: [],
    }
  );
}

export async function setGreetings(greetings: Greetings): Promise<void> {
  await kv.set(GREETINGS_KEY, greetings);
}
