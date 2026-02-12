# Try pgEdge MCP Server

Talk to your PostgreSQL database in plain English. This demo gives you a
running pgEdge MCP Server with the Northwind sample database — ready to
query in under 60 seconds.

## Open in GitHub Codespaces

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/AntTheLimey/try-pgedge-mcp-server)

### Setup

You need an API key from [Anthropic](https://console.anthropic.com/)
or [OpenAI](https://platform.openai.com/).

**Fastest:** Before launching, add a
[Codespace secret](https://github.com/settings/codespaces) named
`PGEDGE_ANTHROPIC_API_KEY` with your key, and grant access to this repo.
Everything starts automatically — no steps required.

**After launch:** If you didn't set a secret, run this in the terminal:

```
./set-key.sh anthropic sk-ant-your-key-here
```

That's it. Services start, and the Web UI opens automatically.

## What's inside

| Component | Details |
|-----------|---------|
| PostgreSQL 17 | pgEdge Enterprise with Spock, pg_stat_statements |
| Northwind dataset | Classic demo database — customers, orders, products (13 tables, ~1000 rows) |
| pgEdge MCP Server | Natural language to SQL, read-only query execution |
| Web UI | Chat interface on port 8081 |

## Try these queries

Login: `demo` / `demo123`

- "What tables are in the database?"
- "Show me the top 10 products by sales"
- "Which customers have placed more than 5 orders?"
- "Analyze order trends by month"
- "Show me the slowest queries from pg_stat_statements"

## Managing the demo

```bash
docker compose logs -f          # View logs
docker compose restart          # Restart services
docker compose down             # Stop
docker compose down -v          # Stop and reset data
```

## Learn more

- [pgEdge MCP Server](https://github.com/pgEdge/pgedge-postgres-mcp) — full source and docs
- [pgEdge docs](https://docs.pgedge.com)
- [pgEdge website](https://www.pgedge.com)
