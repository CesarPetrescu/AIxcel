# AIXcel

AIXcel is a simple spreadsheet prototype written in **Rust** and **Next.js**. It evaluates Excel-style formulas, stores cell data in SQLite, and supports real-time collaboration via WebSockets.

## Features

- Excel formula engine with SUM and AVERAGE functions
- Real-time collaborative editing
- Persistent SQLite storage
- REST API for cell operations and formula evaluation
- Responsive grid interface implemented in React

## Quick Start

Use the provided startup script to run both servers:

```bash
./start.sh
```

The backend will listen on `http://localhost:6889` and the frontend on `http://localhost:3000`.

## Manual Setup

1. **Backend**
   ```bash
   cargo run --manifest-path backend/Cargo.toml
   ```
2. **Frontend**
   ```bash
   cd frontend && npm install && npm run dev
   ```
3. Open <http://localhost:3000> in your browser.

## API Example

Evaluate a formula directly:

```bash
curl -X POST http://localhost:6889/evaluate \
  -H 'Content-Type: application/json' \
  -d '{"expr":"=SUM(1,2,3)"}'
```

## Contributing

Pull requests are welcome! Please run `cargo test` for the backend and `npm run lint` for the frontend before submitting.

## License

This project is licensed under the Apache 2.0 License.
