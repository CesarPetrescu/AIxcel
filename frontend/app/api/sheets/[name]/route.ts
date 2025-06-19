import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://192.168.10.161:6889';

export async function DELETE(_request: NextRequest, { params }: { params: { name: string } }) {
  const resp = await fetch(`${BACKEND_URL}/sheets/${params.name}`, { method: 'DELETE' });
  const text = await resp.text();
  return new NextResponse(text, { status: resp.status });
}
