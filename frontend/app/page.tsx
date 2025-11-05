"use client";
import Link from "next/link";
import styles from "./home.module.css";

export default function Home() {
  return (
    <main className={styles.homeContainer}>
      <div className={styles.heroSection}>
        <h1 className={styles.title}>AIxcel</h1>
        <p className={styles.subtitle}>Your powerful, collaborative spreadsheet application</p>
        <p className={styles.description}>
          Excel-like formulas, real-time collaboration, and persistent storage
        </p>
      </div>

      <div className={styles.sheetsSection}>
        <h2 className={styles.sectionTitle}>Your Spreadsheets</h2>
        <div className={styles.sheetGrid}>
          <Link href="/sheets/default" className={styles.sheetCard}>
            <div className={styles.sheetIcon}>📊</div>
            <h3 className={styles.sheetName}>Default Sheet</h3>
            <p className={styles.sheetDescription}>General purpose spreadsheet</p>
          </Link>

          <Link href="/sheets/finance" className={styles.sheetCard}>
            <div className={styles.sheetIcon}>💰</div>
            <h3 className={styles.sheetName}>Finance Sheet</h3>
            <p className={styles.sheetDescription}>Financial calculations and budgets</p>
          </Link>

          <Link href="/sheets/inventory" className={styles.sheetCard}>
            <div className={styles.sheetIcon}>📦</div>
            <h3 className={styles.sheetName}>Inventory Sheet</h3>
            <p className={styles.sheetDescription}>Track products and stock</p>
          </Link>

          <Link href="/sheets/tasks" className={styles.sheetCard}>
            <div className={styles.sheetIcon}>✅</div>
            <h3 className={styles.sheetName}>Tasks Sheet</h3>
            <p className={styles.sheetDescription}>Manage projects and todos</p>
          </Link>
        </div>
      </div>

      <div className={styles.featuresSection}>
        <h2 className={styles.sectionTitle}>Features</h2>
        <div className={styles.featureGrid}>
          <div className={styles.featureCard}>
            <div className={styles.featureIcon}>🔢</div>
            <h3>Excel Formulas</h3>
            <p>SUM, AVERAGE, and more</p>
          </div>

          <div className={styles.featureCard}>
            <div className={styles.featureIcon}>👥</div>
            <h3>Real-time Collaboration</h3>
            <p>Work together with your team</p>
          </div>

          <div className={styles.featureCard}>
            <div className={styles.featureIcon}>💾</div>
            <h3>Auto-save</h3>
            <p>Never lose your work</p>
          </div>

          <div className={styles.featureCard}>
            <div className={styles.featureIcon}>🎨</div>
            <h3>Cell Formatting</h3>
            <p>Bold, italic, and colors</p>
          </div>
        </div>
      </div>
    </main>
  );
}
