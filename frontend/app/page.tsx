"use client";
import Link from "next/link";

export default function Home() {
  return (
    <main style={{ padding: "2rem" }}>
      <h1>Available Spreadsheets</h1>
      <ul>
        <li><Link href="/sheets/default">Default Sheet</Link></li>
        <li><Link href="/sheets/finance">Finance Sheet</Link></li>
      </ul>
    </main>
  );
}
