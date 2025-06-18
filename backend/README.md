# AIxcel Backend

This is a small Actix-web service that stores spreadsheet cells in a SQLite database.

## Endpoints

- `GET /health` – basic health check.
- `GET /cells` – list all cells.
- `POST /cells` – create or update a cell with `{ row, col, value }` JSON.
- `POST /evaluate` – evaluate an Excel-style formula with `{ expr }` JSON.

The server automatically creates `cells.db` in the working directory. To run:

```bash
cargo run --manifest-path backend/Cargo.toml
```
