import { NextRequest, NextResponse } from "next/server";
import { getMessages, setMessages, Message } from "@/lib/kv";
import { validateAuth } from "@/lib/auth";

export async function GET() {
  const messages = await getMessages();
  return NextResponse.json({ messages });
}

export async function POST(req: NextRequest) {
  if (!validateAuth(req.headers.get("authorization"))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { text } = await req.json();
  if (!text?.trim()) {
    return NextResponse.json({ error: "Text is required" }, { status: 400 });
  }

  const messages = await getMessages();
  const newMsg: Message = {
    id: `msg_${Date.now()}`,
    text: text.trim(),
    createdAt: new Date().toISOString(),
  };
  messages.push(newMsg);
  await setMessages(messages);

  return NextResponse.json({ message: newMsg }, { status: 201 });
}

export async function PUT(req: NextRequest) {
  if (!validateAuth(req.headers.get("authorization"))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id, text } = await req.json();
  if (!id || !text?.trim()) {
    return NextResponse.json({ error: "id and text are required" }, { status: 400 });
  }

  const messages = await getMessages();
  const idx = messages.findIndex((m) => m.id === id);
  if (idx === -1) {
    return NextResponse.json({ error: "Message not found" }, { status: 404 });
  }

  messages[idx].text = text.trim();
  await setMessages(messages);

  return NextResponse.json({ message: messages[idx] });
}

export async function DELETE(req: NextRequest) {
  if (!validateAuth(req.headers.get("authorization"))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { id } = await req.json();
  if (!id) {
    return NextResponse.json({ error: "id is required" }, { status: 400 });
  }

  const messages = await getMessages();
  const filtered = messages.filter((m) => m.id !== id);
  if (filtered.length === messages.length) {
    return NextResponse.json({ error: "Message not found" }, { status: 404 });
  }

  await setMessages(filtered);
  return NextResponse.json({ success: true });
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 204 });
}
