import { NextRequest, NextResponse } from 'next/server';

const BACKEND_URL = process.env.BACKEND_URL || 'http://192.168.10.161:6889';

export async function GET(request: NextRequest) {
  try {
    const sheet = request.nextUrl.searchParams.get('sheet') || 'default';
    const response = await fetch(`${BACKEND_URL}/cells?sheet=${sheet}`);
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
    const sheet = body.sheet || request.nextUrl.searchParams.get('sheet') || 'default';
    body.sheet = sheet;
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
