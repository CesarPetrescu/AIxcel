import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://192.168.10.161:6889';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const sheet = request.nextUrl.searchParams.get('sheet') || 'default';
    interface Cell {
      row: number;
      col: number;
      value: string;
      [key: string]: unknown;
    }
    const cells = (body as Cell[]).map((c) => ({ ...c, sheet }));
    const response = await fetch(`${BACKEND_URL}/cells/bulk`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(cells),
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const result = await response.text();
    return new NextResponse(result, { status: 200 });
  } catch (error) {
    console.error('Error saving cells bulk:', error);
    return NextResponse.json({ error: 'Failed to save cells' }, { status: 500 });
  }
}
