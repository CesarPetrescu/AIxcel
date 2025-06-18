"use client";
import { useEffect, useState } from "react";
import styles from "./page.module.css";

interface Cell {
  row: number;
  col: number;
  value: string;
}

export default function Home() {
  const [cells, setCells] = useState<Cell[]>([]);
  const [row, setRow] = useState(0);
  const [col, setCol] = useState(0);
  const [value, setValue] = useState("");
  const [formula, setFormula] = useState("");

  useEffect(() => {
    fetch("http://localhost:8080/cells")
      .then((res) => res.json())
      .then(setCells)
      .catch(console.error);
  }, []);

  const addCell = async () => {
    await fetch("http://localhost:8080/cells", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ row, col, value }),
    });
    const res = await fetch("http://localhost:8080/cells");
    setCells(await res.json());
  };

  return (
    <main className={styles.container}>
      <h1>AIxcel Demo</h1>
      <table className={styles.table}>
        <thead>
          <tr>
            <th>Row</th>
            <th>Col</th>
            <th>Value</th>
          </tr>
        </thead>
        <tbody>
          {cells.map((c, idx) => (
            <tr key={idx}>
              <td>{c.row}</td>
              <td>{c.col}</td>
              <td>{c.value}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <div className={styles.form}>
        <input
          type="number"
          placeholder="Row"
          value={row}
          onChange={(e) => setRow(Number(e.target.value))}
        />
        <input
          type="number"
          placeholder="Col"
          value={col}
          onChange={(e) => setCol(Number(e.target.value))}
        />
        <input
          type="text"
          placeholder="Value"
          value={value}
          onChange={(e) => setValue(e.target.value)}
        />
        <button onClick={addCell}>Save</button>
        <input
          type="text"
          placeholder="=SUM(1,2)"
          value={formula}
          onChange={(e) => setFormula(e.target.value)}
        />
        <button
          onClick={async () => {
            const res = await fetch("http://localhost:8080/evaluate", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ expr: formula }),
            });
            alert(await res.text());
          }}
        >Eval</button>
      </div>
    </main>
  );
}
