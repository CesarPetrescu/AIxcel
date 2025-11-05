import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "AIxcel - Collaborative Spreadsheet",
  description: "A powerful collaborative spreadsheet application with Excel-like formulas, real-time updates, and persistent storage",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        {children}
      </body>
    </html>
  );
}
