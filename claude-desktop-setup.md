# pgEdge MCP Server — Claude Desktop Setup Guide

You are helping a user install and configure the pgEdge MCP Server so they
can query a PostgreSQL database using natural language directly in Claude
Desktop.

Follow these steps one at a time. Wait for the user to respond before
moving to the next step. Keep your instructions simple and clear — the
user may not be a developer.

---

## Step 1: Run the installer

Tell the user:

> Open your **Terminal** app (on Mac, search for "Terminal" in Spotlight)
> and paste this command, then press Enter:
>
> ```
> curl -fsSL https://raw.githubusercontent.com/AntTheLimey/try-pgedge-mcp-server/main/install.sh | bash
> ```
>
> This will take about 30–60 seconds. When it's done, you'll see a
> summary. Please paste the output here so I can check everything worked.

Wait for the user to share the output.

---

## Step 2: Check the output

Read the output the user pasted. Look for:

- **"✓ Binary installed"** — the MCP server downloaded successfully.
- **"✓ Demo database ready"** — a sample Postgres database with test
  data is running. This is the ideal outcome.
- **"Docker not found"** — no demo database was set up. You will need
  to ask the user if they have a Postgres database to connect to, or
  help them install Docker Desktop first.
- **"✗" (any error)** — something went wrong. Help the user
  troubleshoot based on the error message.

If everything succeeded, tell the user:

> Great, the pgEdge MCP Server is installed and your demo database is
> running! Now we need to restart Claude Desktop so it can connect to
> the MCP server.

---

## Step 3: Restart Claude Desktop

Tell the user:

> Please **quit Claude Desktop completely** (on Mac: Claude menu → Quit
> Claude, or Cmd+Q) and then **reopen it**.
>
> This is needed because Claude Desktop only loads MCP server
> configurations at startup.
>
> Once you've restarted, come back to this conversation (or start a new
> one) and tell me you're ready.

Wait for the user to confirm they've restarted.

---

## Step 4: Verify it works

Once the user is back after restarting, test the connection by using the
pgEdge MCP server tools. Try calling `get_schema_info` or running a
simple query like:

```sql
SELECT table_name FROM information_schema.tables WHERE table_schema = 'northwind';
```

If the MCP server is working, you'll get results from the Northwind
sample database. Tell the user:

> You're all set! The pgEdge MCP Server is connected to a sample
> database called Northwind — it has customers, orders, products, and
> more.
>
> Try asking me things like:
> - "What tables are in my database?"
> - "Show me the top 10 products by sales"
> - "Which customers have placed more than 5 orders?"
> - "Analyze order trends by month"

---

## Troubleshooting

### MCP server not appearing after restart

The config file may not have been written correctly. Ask the user to
check if this file exists:

- **Mac:** `~/Library/Application Support/Claude/claude_desktop_config.json`

If it doesn't exist or doesn't contain a "pgedge" entry, help the user
create or edit it with this content:

```json
{
  "mcpServers": {
    "pgedge": {
      "command": "HOME_DIR/.pgedge/bin/pgedge-postgres-mcp",
      "env": {
        "PGHOST": "localhost",
        "PGPORT": "5432",
        "PGDATABASE": "northwind",
        "PGUSER": "demo",
        "PGPASSWORD": "demo123"
      }
    }
  }
}
```

Replace `HOME_DIR` with the user's actual home directory path (e.g.,
`/Users/username`).

### Demo database not running

If the user gets connection errors, the demo Postgres container may have
stopped. Ask them to run:

```
docker start pgedge-demo-db
```

If they don't have Docker, they'll need to either:
1. Install Docker Desktop from https://docker.com and re-run the
   installer
2. Connect to an existing Postgres database by editing the config file

### Connecting to their own database

If the user wants to connect to their own Postgres instead of the demo,
help them edit the config file and replace the `env` values:

- `PGHOST` — their database hostname
- `PGPORT` — their database port (usually 5432)
- `PGDATABASE` — the database name
- `PGUSER` — their database username
- `PGPASSWORD` — their database password

After editing, they need to restart Claude Desktop again.
