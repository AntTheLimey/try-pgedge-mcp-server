#!/bin/bash
# pgEdge MCP Server — one-command installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/AntTheLimey/try-pgedge-mcp-server/main/install.sh | bash
#
# What it does:
#   1. Downloads the pgEdge MCP Server binary for your platform
#   2. If Docker is available, starts a demo Postgres with sample data
#   3. Configures Claude Code (.mcp.json) and/or Claude Desktop
#
set -e

# ─── Configuration ───────────────────────────────────────────────────────────

INSTALL_DIR="$HOME/.pgedge"
BIN_DIR="$INSTALL_DIR/bin"
DEMO_DIR="$INSTALL_DIR/demo"
REPO="pgEdge/pgedge-postgres-mcp"
DEMO_PORT=5432

# ─── Helper functions ────────────────────────────────────────────────────────

info()  { echo "  ℹ  $*"; }
ok()    { echo "  ✓  $*"; }
warn()  { echo "  ⚠  $*"; }
fail()  { echo "  ✗  $*" >&2; exit 1; }

# ─── Detect platform ────────────────────────────────────────────────────────

detect_platform() {
  local os arch

  case "$(uname -s)" in
    Darwin) os="darwin" ;;
    Linux)  os="linux" ;;
    MINGW*|MSYS*|CYGWIN*) os="windows" ;;
    *) fail "Unsupported operating system: $(uname -s)" ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64)  arch="x86_64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) fail "Unsupported architecture: $(uname -m)" ;;
  esac

  OS="$os"
  ARCH="$arch"

  if [ "$os" = "windows" ]; then
    EXT="zip"
  else
    EXT="tar.gz"
  fi
}

# ─── Get latest release version ─────────────────────────────────────────────

get_latest_version() {
  VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)

  if [ -z "$VERSION" ]; then
    fail "Could not determine latest release version"
  fi

  # Strip leading 'v' for the asset filename
  VERSION_NUM="${VERSION#v}"
}

# ─── Download and install binary ────────────────────────────────────────────

download_binary() {
  local asset_name="pgedge-postgres-mcp-server_${VERSION_NUM}_${OS}_${ARCH}.${EXT}"
  local url="https://github.com/$REPO/releases/download/$VERSION/$asset_name"
  local tmp_dir

  tmp_dir=$(mktemp -d)

  info "Downloading pgEdge MCP Server $VERSION ($OS/$ARCH)..."

  curl -fsSL -o "$tmp_dir/$asset_name" "$url" \
    || fail "Download failed. URL: $url"

  mkdir -p "$BIN_DIR"

  if [ "$EXT" = "zip" ]; then
    unzip -qo "$tmp_dir/$asset_name" -d "$tmp_dir/extracted"
  else
    tar xzf "$tmp_dir/$asset_name" -C "$tmp_dir/extracted" 2>/dev/null \
      || (mkdir -p "$tmp_dir/extracted" && tar xzf "$tmp_dir/$asset_name" -C "$tmp_dir/extracted")
  fi

  cp "$tmp_dir/extracted/pgedge-postgres-mcp" "$BIN_DIR/pgedge-postgres-mcp"
  chmod +x "$BIN_DIR/pgedge-postgres-mcp"

  rm -rf "$tmp_dir"

  ok "Binary installed: $BIN_DIR/pgedge-postgres-mcp"
}

# ─── Start demo Postgres with Northwind ─────────────────────────────────────

setup_demo_db() {
  # Check if port is already in use
  if lsof -i ":$DEMO_PORT" >/dev/null 2>&1 || ss -tlnp "sport = :$DEMO_PORT" >/dev/null 2>&1; then
    # Check if it's our demo container
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "pgedge-demo-db"; then
      ok "Demo database already running on port $DEMO_PORT"
      DB_CONFIGURED=true
      return
    fi
    warn "Port $DEMO_PORT is already in use. Skipping demo database."
    warn "The MCP server is installed but you'll need to configure your own database."
    DB_CONFIGURED=false
    return
  fi

  mkdir -p "$DEMO_DIR"

  # Write a minimal docker-compose for just the demo database
  cat > "$DEMO_DIR/docker-compose.yml" << 'COMPOSE'
services:
  postgres:
    image: ghcr.io/pgedge/pgedge-postgres:17-spock5-standard
    container_name: pgedge-demo-db
    command: postgres -c listen_addresses='*' -c shared_preload_libraries='pg_stat_statements'
    environment:
      POSTGRES_USER: demo
      POSTGRES_PASSWORD: demo123
      POSTGRES_DB: northwind
    volumes:
      - pgdata:/var/lib/postgresql/data
    configs:
      - source: load-northwind
        target: /docker-entrypoint-initdb.d/01-load-northwind.sh
        mode: 0755
      - source: enable-extensions
        target: /docker-entrypoint-initdb.d/02-enable-extensions.sh
        mode: 0755
    ports:
      - "5432:5432"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U demo -d northwind"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 30s

volumes:
  pgdata:
    driver: local

configs:
  load-northwind:
    content: |-
      #!/usr/bin/env bash
      set -e
      echo "Loading Northwind dataset..."
      curl -fsSL -o /tmp/northwind.sql https://downloads.pgedge.com/platform/examples/northwind/northwind.sql
      psql -v ON_ERROR_STOP=1 --username "$$POSTGRES_USER" --dbname "$$POSTGRES_DB" -f /tmp/northwind.sql
      rm -f /tmp/northwind.sql
      echo "Northwind dataset loaded"
  enable-extensions:
    content: |-
      #!/usr/bin/env bash
      set -e
      psql -v ON_ERROR_STOP=1 --username "$$POSTGRES_USER" --dbname "$$POSTGRES_DB" \
        -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
      echo "Extensions enabled"
COMPOSE

  info "Starting demo Postgres with Northwind sample data..."
  docker compose -f "$DEMO_DIR/docker-compose.yml" up -d 2>/dev/null \
    || docker-compose -f "$DEMO_DIR/docker-compose.yml" up -d 2>/dev/null \
    || { warn "Failed to start demo database."; DB_CONFIGURED=false; return; }

  # Wait for healthy
  info "Waiting for database to be ready..."
  for i in $(seq 1 24); do
    if docker exec pgedge-demo-db pg_isready -U demo -d northwind >/dev/null 2>&1; then
      ok "Demo database ready (northwind on localhost:$DEMO_PORT)"
      DB_CONFIGURED=true
      return
    fi
    sleep 5
  done

  warn "Database is starting but not yet healthy. It may need another minute."
  DB_CONFIGURED=true
}

# ─── Configure Claude Code ──────────────────────────────────────────────────

configure_claude_code() {
  local mcp_json=".mcp.json"
  local binary_path="$BIN_DIR/pgedge-postgres-mcp"
  local new_entry

  if [ "$DB_CONFIGURED" = true ]; then
    new_entry=$(cat << ENTRY
{
  "mcpServers": {
    "pgedge": {
      "command": "$binary_path",
      "env": {
        "PGHOST": "localhost",
        "PGPORT": "$DEMO_PORT",
        "PGDATABASE": "northwind",
        "PGUSER": "demo",
        "PGPASSWORD": "demo123"
      }
    }
  }
}
ENTRY
)
  else
    new_entry=$(cat << ENTRY
{
  "mcpServers": {
    "pgedge": {
      "command": "$binary_path",
      "env": {
        "PGHOST": "localhost",
        "PGPORT": "5432",
        "PGDATABASE": "your_database",
        "PGUSER": "your_user",
        "PGPASSWORD": "your_password"
      }
    }
  }
}
ENTRY
)
  fi

  # Merge with existing .mcp.json if present
  if [ -f "$mcp_json" ]; then
    if command -v python3 &>/dev/null; then
      python3 -c "
import json, sys
existing = json.load(open('$mcp_json'))
new = json.loads('''$new_entry''')
if 'mcpServers' not in existing:
    existing['mcpServers'] = {}
existing['mcpServers'].update(new['mcpServers'])
json.dump(existing, open('$mcp_json', 'w'), indent=2)
print('  ✓  Claude Code: merged pgedge into existing $mcp_json')
" 2>/dev/null && return
    fi
  fi

  # No existing file or merge failed — write fresh
  echo "$new_entry" > "$mcp_json"
  ok "Claude Code: wrote $mcp_json"
}

# ─── Configure Claude Desktop ───────────────────────────────────────────────

configure_claude_desktop() {
  local config_file binary_path="$BIN_DIR/pgedge-postgres-mcp"

  # Find Claude Desktop config
  case "$OS" in
    darwin)
      config_file="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
      ;;
    linux)
      config_file="$HOME/.config/Claude/claude_desktop_config.json"
      ;;
    *)
      return
      ;;
  esac

  # Check if Claude Desktop directory exists
  local config_dir
  config_dir=$(dirname "$config_file")
  if [ ! -d "$config_dir" ]; then
    info "Claude Desktop not detected (no config directory at $config_dir)"
    return
  fi

  local db_host="localhost"
  local db_port="$DEMO_PORT"
  local db_name="northwind"
  local db_user="demo"
  local db_pass="demo123"

  if [ "$DB_CONFIGURED" != true ]; then
    db_name="your_database"
    db_user="your_user"
    db_pass="your_password"
  fi

  if [ -f "$config_file" ] && command -v python3 &>/dev/null; then
    python3 -c "
import json
config_file = '$config_file'
try:
    with open(config_file) as f:
        config = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    config = {}

if 'mcpServers' not in config:
    config['mcpServers'] = {}

config['mcpServers']['pgedge'] = {
    'command': '$binary_path',
    'env': {
        'PGHOST': '$db_host',
        'PGPORT': '$db_port',
        'PGDATABASE': '$db_name',
        'PGUSER': '$db_user',
        'PGPASSWORD': '$db_pass'
    }
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
print('  ✓  Claude Desktop: configured (restart Claude Desktop to activate)')
" 2>/dev/null && return
  fi

  # Fallback: write new config if no existing file
  mkdir -p "$config_dir"
  cat > "$config_file" << DESKTOP
{
  "mcpServers": {
    "pgedge": {
      "command": "$binary_path",
      "env": {
        "PGHOST": "$db_host",
        "PGPORT": "$db_port",
        "PGDATABASE": "$db_name",
        "PGUSER": "$db_user",
        "PGPASSWORD": "$db_pass"
      }
    }
  }
}
DESKTOP
  ok "Claude Desktop: wrote config (restart Claude Desktop to activate)"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  pgEdge MCP Server — Installer"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  detect_platform
  get_latest_version
  download_binary

  DB_CONFIGURED=false

  # Try Docker for demo database
  if command -v docker &>/dev/null && docker info >/dev/null 2>&1; then
    setup_demo_db
  else
    info "Docker not found. Skipping demo database."
    info "You can connect to your own Postgres by editing the config files."
  fi

  echo ""
  configure_claude_code
  configure_claude_desktop

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Installation complete!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Binary:   $BIN_DIR/pgedge-postgres-mcp"

  if [ "$DB_CONFIGURED" = true ]; then
    echo "  Database: northwind on localhost:$DEMO_PORT (demo/demo123)"
    echo ""
    echo "  Try asking Claude:"
    echo "    \"What tables are in my database?\""
    echo "    \"Show me the top 10 products by sales\""
    echo "    \"Which customers have placed more than 5 orders?\""
  else
    echo "  Database: not configured"
    echo ""
    echo "  Edit .mcp.json (Claude Code) or Claude Desktop config"
    echo "  to add your Postgres connection details."
  fi

  echo ""
  echo "  Claude Code:    ready (start a new conversation)"
  echo "  Claude Desktop: restart the app to activate"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

main
