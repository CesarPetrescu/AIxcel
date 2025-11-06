import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://192.168.10.161:6889';

interface Cell {
  row: number;
  col: number;
  value: string;
  font_weight?: string;
  font_style?: string;
  background_color?: string;
  sheet?: string;
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json() as Cell[];
    const sheet = request.nextUrl.searchParams.get('sheet') || 'default';
    const cells = body.map((c: Cell) => ({ ...c, sheet }));
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
