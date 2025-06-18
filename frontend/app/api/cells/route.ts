import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://127.0.0.1:6889';

export async function GET() {
  try {
    const response = await fetch(`${BACKEND_URL}/cells`);
    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('Error fetching cells:', error);
    return NextResponse.json({ error: 'Failed to fetch cells' }, { status: 500 });
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const response = await fetch(`${BACKEND_URL}/cells`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const result = await response.text();
    return new NextResponse(result, { status: 200 });
  } catch (error) {
    console.error('Error saving cell:', error);
    return NextResponse.json({ error: 'Failed to save cell' }, { status: 500 });
  }
}
