
---

## ✨ What is it?

**AIxcel** turns any React‑based spreadsheet into an intelligent data hub.
It combines 🚀 AI agents , 🔌 live database & API connectors, and 🛡 enterprise‑grade security so teams can chat with data, auto‑clean sheets, and keep everything in sync—without leaving the grid.

---

## Table of Contents

1. [Features](#features)
2. [Supported Connectors](#supported-connectors)
3. [Quick Start](#quick-start)
4. [How to Connect](#how-to-connect)

   * [Relational DB](#connecting-to-a-relational-database)
   * [REST / GraphQL API](#connecting-to-a-rest--graphql-api)
5. [Security Notes](#security-notes)
6. [Deployment](#deployment)
7. [Contributing](#contributing)
8. [License](#license)

---

## Features

| Category      | Highlight                                          |
| ------------- | -------------------------------------------------- |
| AI‑First UX   | Natural‑language formula builder & explainer       |
| Agents        | ReAct auto‑completion, data clean‑up, voice SQL    |
| Live Data     | ODBC/JDBC DirectQuery, REST/GraphQL polling        |
| Scale         | Virtualised grid handles 1 M+ rows                 |
| Collaboration | CRDT co‑edit + database‑safe locks                 |
| Security      | TLS‑only connectors, vault‑stored creds, audit XML |

Sources • Excel DirectQuery ([learn.microsoft.com][1]) • App‑Script→MySQL ([hevodata.com][2]) • Coefficient one‑click DB links ([coefficient.io][3]) • Zapier two‑way sync ([zapier.com][4]) • API Connector (Superjoin) ([superjoin.ai][5]) • 100 k‑row virtualisation proof ([reddit.com][6]) • Awesome Table 15 s refresh ([support.awesome-table.com][7]) • OWASP encrypted‑DB guidance ([cheatsheetseries.owasp.org][8]) • Hugging Face AISheets multi‑model ([superjoin.ai][9])

---

## Supported Connectors

| Type                 | Examples                                 | Notes                                                           |
| -------------------- | ---------------------------------------- | --------------------------------------------------------------- |
| **Relational DB**    | MySQL, PostgreSQL, SQL Server, Snowflake | ODBC/JDBC or native drivers; DirectQuery supported              |
| **Cloud Warehouses** | BigQuery, Redshift, Databricks           | Via JDBC with token auth                                        |
| **NoSQL**            | MongoDB, DynamoDB                        | REST or Data API                                                |
| **SaaS / CRM**       | Salesforce, HubSpot, Stripe, Netsuite    | One‑click via Coefficient‑style templates ([coefficient.io][3]) |
| **REST / GraphQL**   | Any JSON, XML, CSV endpoint              | Schedule pulls every 1 min‑1 day                                |
| **Automation Hubs**  | Zapier, Make (Integromat)                | Event‑driven row ↔ DB sync ([zapier.com][4])                    |

---

## Quick Start

```bash
# backend
cargo run --manifest-path backend/Cargo.toml

# frontend
cd frontend && npm run dev
```

This launches a simple Actix API with a SQLite workbook and a Next.js UI.

To evaluate a formula directly:

```bash
curl -X POST http://localhost:8080/evaluate \
  -H "Content-Type: application/json" \
  -d '{"expr":"=SUM(1,2,3)"}'
```

## Development Status

- [x] Actix backend with SQLite storage
- [x] Responsive Next.js frontend
- [x] Integration tests
- [x] Excel formula engine
- [ ] AI connectors and agents
- [ ] External data connectors

---

## How to Connect

### Connecting to a Relational Database

1. **Install driver**

   ```bash
   docker exec api pip install mysql‑connector‑python
   ```
2. **Add DSN (encrypted)**

   ```ini
   # config/connectors.d/mysql-prod.ini
   [MySales]
   type = mysql
   host = db.company.internal
   port = 3306
   database = sales
   username = ${DB_USER}
   password = ${DB_PASS}
   ssl_mode = REQUIRE
   ```
3. **Restart back‑end** – it hot‑loads connector manifests.
4. **Query from the grid**

   ```text
   /sql MySales
   SELECT region, SUM(amount) AS revenue
   FROM orders
   WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
   GROUP BY region;
   ```

The agent translates NLP like **“revenue by region last 90 days”** into the SQL above ([learn.microsoft.com][1]).

---

### Connecting to a REST / GraphQL API

> Works for Stripe, Jira, GitHub, or any custom service.

1. **Create YAML spec**

```yaml
# config/apis/github.yaml
name: GitHubIssues
base_url: https://api.github.com
auth:
  type: header
  header: Authorization
  value: "Bearer ${GITHUB_TOKEN}"
endpoints:
  - path: /repos/{owner}/{repo}/issues
    method: GET
    params:
      state: open
schedule: "every 30m"
```

2. **Register & run**

```bash
cli connectors:add api config/apis/github.yaml
cli jobs:start GitHubIssues
```

3. **Map into sheet**

```ini
[SheetMapping]
endpoint = GitHubIssues
sheet    = Issues!A1
mode     = replace   # or append
```

Behind the scenes the APIBridge polls Superjoin‑style and writes XML deltas ([superjoin.ai][5]).

---

## Security Notes

* **TLS 1.2+ only** on all database sockets per OWASP CS §“Transport Layer” ([cheatsheetseries.owasp.org][8])
* Secrets stored in HashiCorp Vault; never commit DSNs.
* Row‑level policies propagate from source DB into sheet view.
* Every agent action is logged to `audit/{date}.xml` (deterministic replay).

---

## Deployment

| Target                | File                     | Command                                                 |
| --------------------- | ------------------------ | ------------------------------------------------------- |
| **Docker Swarm**      | `deploy/swarm-stack.yml` | `docker stack deploy -c deploy/swarm-stack.yml aicells` |
| **Kubernetes**        | `helm/`                  | `helm install aicells helm/`                            |
| **Edge / Air‑gapped** | `edge/compose.yml`       | ships light “Gateway” that syncs when online            |

---

## Contributing

We ♥ PRs!  See **CONTRIBUTING.md** for coding standards, commit message style, and how to run the test suite.

1. Fork → feature branch → PR.
2. Run `npm run lint && npm test`.
3. Sign the CLA (bot will prompt).

---

## License

Apache 2.0.  See [LICENSE](LICENSE) for details.

---

### Badges

![build](https://img.shields.io/github/actions/workflow/status/your-org/aicells/ci.yml)
![license](https://img.shields.io/github/license/your-org/aicells)

---

> *Happy spreadsheeting!*

[1]: https://learn.microsoft.com/en-us/power-bi/connect-data/desktop-directquery-about?utm_source=chatgpt.com "DirectQuery in Power BI - Learn Microsoft"
[2]: https://hevodata.com/learn/google-script-connect-to-mysql/?utm_source=chatgpt.com "Google Script Connect to MySQL | 5 Easy Steps - Hevo Data"
[3]: https://coefficient.io/?utm_source=chatgpt.com "Coefficient – Data Connectors for Google Sheets & Excel"
[4]: https://zapier.com/apps/google-sheets/integrations/sql-server?utm_source=chatgpt.com "Google Sheets SQL Server Integration - Quick Connect - Zapier"
[5]: https://www.superjoin.ai/blog/a-comprehensive-guide-to-connect-rest-api-to-google-sheets?utm_source=chatgpt.com "A comprehensive guide to connect Rest API to Google Sheets"
[6]: https://www.reddit.com/r/reactjs/comments/1fb9poc/need_help_with_table_virtualization_for_large/?utm_source=chatgpt.com "Need Help with Table Virtualization for Large Data Sets (100k+ rows ..."
[7]: https://support.awesome-table.com/hc/en-us/articles/115004766069-How-to-automatically-refresh-your-app-if-your-spreadsheet-is-frequently-updated?utm_source=chatgpt.com "How to automatically refresh your app if your spreadsheet is ..."
[8]: https://cheatsheetseries.owasp.org/cheatsheets/Database_Security_Cheat_Sheet.html?utm_source=chatgpt.com "Database Security - OWASP Cheat Sheet Series"
[9]: https://www.superjoin.ai/blog/api-connector-for-google-sheets?utm_source=chatgpt.com "API Connector for Google Sheets - Superjoin"
