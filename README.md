# Try pgEdge MCP Server

Talk to your PostgreSQL database in plain English. This demo gives you a
running pgEdge MCP Server with the Northwind sample database — ready to
query in under 60 seconds.

## Open in GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/AntTheLimey/try-pgedge-mcp-server)

### Before you launch

You'll need an API key from one of:

- [Anthropic](https://console.anthropic.com/) (recommended)
- [OpenAI](https://platform.openai.com/)

**Option A (smoothest):** Add your key as a
[Codespace secret](https://github.com/settings/codespaces) before
launching. Create a secret named `PGEDGE_ANTHROPIC_API_KEY`, paste your
key, and grant access to this repo. The demo picks it up automatically.

**Option B:** Launch the Codespace, then run in the terminal:

```bash
./set-key.sh anthropic sk-ant-your-key-here
docker compose down && docker compose up -d
```

## What's inside

| Component | Details |
|-----------|---------|
| PostgreSQL 17 | pgEdge Enterprise with Spock, pg_stat_statements |
| Northwind dataset | Classic demo database — customers, orders, products (13 tables, ~1000 rows) |
| pgEdge MCP Server | Natural language to SQL, read-only query execution |
| Web UI | Chat interface on port 8081 |

## Try these queries

Once the Web UI opens in your browser (login: `demo` / `demo123`):

- "What tables are in the database?"
- "Show me the top 10 products by sales"
- "Which customers have placed more than 5 orders?"
- "Analyze order trends by month"
- "Show me the slowest queries from pg_stat_statements"

## Managing the demo

```bash
# View logs
docker compose logs -f

# Restart services
docker compose restart

# Stop everything
docker compose down

# Stop and reset data
docker compose down -v
```

## Learn more

- [pgEdge MCP Server](https://github.com/pgEdge/pgedge-postgres-mcp) — full source and docs
- [pgEdge docs](https://docs.pgedge.com)
- [pgEdge website](https://www.pgedge.com)
