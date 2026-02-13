# Install locally (Claude Code or Claude Desktop)

One command installs the pgEdge MCP Server binary and a demo Postgres
database with sample data.

## macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/AntTheLimey/try-pgedge-mcp-server/main/install.sh | bash
```

## Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/AntTheLimey/try-pgedge-mcp-server/main/install.ps1 | iex
```

## What the installer does

1. Downloads the pgEdge MCP Server binary
2. Optionally starts a demo Postgres container (requires Docker)
3. Configures Claude Code (`.mcp.json`) and Claude Desktop automatically

After installing, restart Claude Desktop and ask:
*"What tables are in my database?"*

## Claude Desktop setup guide

For step-by-step Claude Desktop configuration and troubleshooting, see
[claude-desktop-setup.md](claude-desktop-setup.md).
