import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://192.168.10.161:6889';

interface CellPosition {
  row: number;
  col: number;
  sheet?: string;
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json() as { cells: CellPosition[] };
    const sheet = request.nextUrl.searchParams.get('sheet') || 'default';
    const cells = body.cells.map((c: CellPosition) => ({ ...c, sheet }));
    const response = await fetch(`${BACKEND_URL}/cells/clear`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ cells }),
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const result = await response.text();
    return new NextResponse(result, { status: 200 });
  } catch (error) {
    console.error('Error clearing cells:', error);
    return NextResponse.json({ error: 'Failed to clear cells' }, { status: 500 });
  }
}
