import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://192.168.10.161:6889';

export async function GET() {
  const resp = await fetch(`${BACKEND_URL}/sheets`);
  const data = await resp.json();
  return NextResponse.json(data);
}

export async function POST(request: NextRequest) {
  const body = await request.json();
  const resp = await fetch(`${BACKEND_URL}/sheets`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  const data = await resp.json();
  return NextResponse.json(data);
}
