"use client";
import Link from "next/link";
import { useEffect, useState } from "react";

interface SheetName {
  name: string;
}

export default function Home() {
  const [sheets, setSheets] = useState<SheetName[]>([]);

  useEffect(() => {
    fetch("/api/sheets")
      .then((res) => res.json())
      .then(setSheets);
  }, []);

  return (
    <main style={{ padding: "2rem" }}>
      <h1>Available Spreadsheets</h1>
      <ul>
        {sheets.map((s) => (
          <li key={s.name}>
            <Link href={`/sheets/${s.name}`}>{s.name}</Link>
          </li>
        ))}
      </ul>
    </main>
  );
}
