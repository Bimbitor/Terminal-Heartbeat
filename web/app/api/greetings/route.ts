import { NextRequest, NextResponse } from "next/server";
import { getGreetings, setGreetings, Greeting, Greetings } from "@/lib/kv";
import { validateAuth } from "@/lib/auth";

type Period = keyof Greetings;
const VALID_PERIODS: Period[] = ["morning", "afternoon", "night"];

export async function GET() {
  const greetings = await getGreetings();
  return NextResponse.json({ greetings });
}

export async function POST(req: NextRequest) {
  if (!validateAuth(req.headers.get("authorization"))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { period, text } = await req.json();
  if (!VALID_PERIODS.includes(period) || !text?.trim()) {
    return NextResponse.json(
      { error: "Valid period (morning/afternoon/night) and text are required" },
      { status: 400 }
    );
  }

  const greetings = await getGreetings();
  const newGreeting: Greeting = {
    id: `grt_${Date.now()}`,
    text: text.trim(),
  };
  greetings[period as Period].push(newGreeting);
  await setGreetings(greetings);

  return NextResponse.json({ greeting: newGreeting }, { status: 201 });
}

export async function PUT(req: NextRequest) {
  if (!validateAuth(req.headers.get("authorization"))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { period, id, text } = await req.json();
  if (!VALID_PERIODS.includes(period) || !id || !text?.trim()) {
    return NextResponse.json(
      { error: "period, id, and text are required" },
      { status: 400 }
    );
  }

  const greetings = await getGreetings();
  const list = greetings[period as Period];
  const idx = list.findIndex((g) => g.id === id);
  if (idx === -1) {
    return NextResponse.json({ error: "Greeting not found" }, { status: 404 });
  }

  list[idx].text = text.trim();
  await setGreetings(greetings);

  return NextResponse.json({ greeting: list[idx] });
}

export async function DELETE(req: NextRequest) {
  if (!validateAuth(req.headers.get("authorization"))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { period, id } = await req.json();
  if (!VALID_PERIODS.includes(period) || !id) {
    return NextResponse.json({ error: "period and id are required" }, { status: 400 });
  }

  const greetings = await getGreetings();
  const list = greetings[period as Period];
  const filtered = list.filter((g) => g.id !== id);
  if (filtered.length === list.length) {
    return NextResponse.json({ error: "Greeting not found" }, { status: 404 });
  }

  greetings[period as Period] = filtered;
  await setGreetings(greetings);

  return NextResponse.json({ success: true });
}

export async function OPTIONS() {
  return new NextResponse(null, { status: 204 });
}
