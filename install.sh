#!/bin/bash
# pgEdge MCP Server — one-command installer
#
# Usage (interactive, in a terminal):
#   curl -fsSL https://raw.githubusercontent.com/AntTheLimey/try-pgedge-mcp-server/main/install.sh | bash
#
# Usage (non-interactive, via Claude Code):
#   curl -fsSL .../install.sh | bash -s -- --demo
#   curl -fsSL .../install.sh | bash -s -- --db-host=localhost --db-port=5432 --db-name=mydb --db-user=me --db-pass=secret
#
# What it does:
#   1. Downloads the pgEdge MCP Server binary for your platform
#   2. Helps you connect to a database (your own or a demo with sample data)
#   3. Configures Claude Code (.mcp.json) and/or Claude Desktop
#
set -e

# ─── Configuration ───────────────────────────────────────────────────────────

INSTALL_DIR="$HOME/.pgedge"
BIN_DIR="$INSTALL_DIR/bin"
DEMO_DIR="$INSTALL_DIR/demo"
REPO="pgEdge/pgedge-postgres-mcp"
DEMO_PORT=5432

# ─── Parse flags (for non-interactive / Claude Code usage) ───────────────────

MODE=""
DB_HOST="" DB_PORT="" DB_NAME="" DB_USER="" DB_PASS=""

for arg in "$@"; do
  case "$arg" in
    --demo)          MODE="demo" ;;
    --own-db)        MODE="own" ;;
    --db-host=*)     DB_HOST="${arg#*=}" ;;
    --db-port=*)     DB_PORT="${arg#*=}" ;;
    --db-name=*)     DB_NAME="${arg#*=}" ;;
    --db-user=*)     DB_USER="${arg#*=}" ;;
    --db-pass=*)     DB_PASS="${arg#*=}" ;;
    --install-docker) MODE="install-docker" ;;
  esac
done

# ─── Helper functions ────────────────────────────────────────────────────────

info()  { echo "  ℹ  $*"; }
ok()    { echo "  ✓  $*"; }
warn()  { echo "  ⚠  $*"; }
fail()  { echo "  ✗  $*" >&2; exit 1; }

# Read from /dev/tty if available (works even when script is piped from curl)
ask() {
  local prompt="$1" var="$2"
  if [ -t 0 ] || [ -e /dev/tty ]; then
    read -p "$prompt" "$var" < /dev/tty
  else
    # Non-interactive — return empty (caller handles default)
    eval "$var=''"
  fi
}

has_tty() {
  [ -t 0 ] || [ -e /dev/tty ]
}

# ─── Detect platform ────────────────────────────────────────────────────────

detect_platform() {
  case "$(uname -s)" in
    Darwin) OS="darwin" ;;
    Linux)  OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
    *) fail "Unsupported operating system: $(uname -s)" ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64)  ARCH="x86_64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) fail "Unsupported architecture: $(uname -m)" ;;
  esac

  if [ "$OS" = "windows" ]; then EXT="zip"; else EXT="tar.gz"; fi
}

# ─── Get latest release version ─────────────────────────────────────────────

get_latest_version() {
  VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
  [ -z "$VERSION" ] && fail "Could not determine latest release version"
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
    || fail "Download failed. Check your internet connection."

  mkdir -p "$BIN_DIR"

  if [ "$EXT" = "zip" ]; then
    unzip -qo "$tmp_dir/$asset_name" -d "$tmp_dir/extracted"
  else
    mkdir -p "$tmp_dir/extracted"
    tar xzf "$tmp_dir/$asset_name" -C "$tmp_dir/extracted"
  fi

  cp "$tmp_dir/extracted/pgedge-postgres-mcp" "$BIN_DIR/pgedge-postgres-mcp"
  chmod +x "$BIN_DIR/pgedge-postgres-mcp"
  rm -rf "$tmp_dir"

  ok "Binary installed: $BIN_DIR/pgedge-postgres-mcp"
}

# ─── Docker detection and installation ──────────────────────────────────────

has_docker() {
  command -v docker &>/dev/null && docker info >/dev/null 2>&1
}

install_docker() {
  echo ""
  info "Installing Docker..."
  echo ""

  case "$OS" in
    darwin)
      if command -v brew &>/dev/null; then
        info "Installing Docker Desktop via Homebrew (this may take a few minutes)..."
        brew install --cask docker
        info "Docker Desktop installed. Please open Docker Desktop from"
        info "your Applications folder, wait for it to start, then re-run"
        info "this installer."
        exit 0
      else
        echo ""
        echo "  Docker Desktop needs to be installed manually on macOS."
        echo ""
        echo "  1. Download it from: https://www.docker.com/products/docker-desktop/"
        echo "  2. Open the .dmg and drag Docker to Applications"
        echo "  3. Launch Docker Desktop and wait for it to start"
        echo "  4. Re-run this installer"
        echo ""
        exit 0
      fi
      ;;
    linux)
      info "Installing Docker Engine..."
      curl -fsSL https://get.docker.com | sh
      if has_docker; then
        ok "Docker installed successfully"
      else
        warn "Docker installed but may need a logout/login to take effect."
        warn "Try: sudo usermod -aG docker \$USER && newgrp docker"
        warn "Then re-run this installer."
        exit 0
      fi
      ;;
    *)
      echo "  Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/"
      exit 0
      ;;
  esac
}

# ─── Database choice ────────────────────────────────────────────────────────

choose_database() {
  # If mode was set via flags, skip prompts
  if [ "$MODE" = "demo" ]; then
    setup_demo_database
    return
  fi

  if [ "$MODE" = "own" ]; then
    setup_own_database
    return
  fi

  if [ "$MODE" = "install-docker" ]; then
    install_docker
    setup_demo_database
    return
  fi

  # Non-interactive (Claude Code without flags) — output choices for Claude
  if ! has_tty; then
    echo ""
    echo "DATABASE_CHOICE_NEEDED"
    echo "The MCP server needs a PostgreSQL database to connect to."
    echo "Options:"
    echo "  1. Demo database — sample Northwind data, requires Docker"
    echo "  2. Your own database — provide connection details"
    echo ""
    echo "Re-run with flags:"
    echo "  --demo                              (start demo database with Docker)"
    echo "  --install-docker                    (install Docker first, then demo)"
    echo "  --own-db --db-host=HOST --db-port=PORT --db-name=DB --db-user=USER --db-pass=PASS"
    echo ""
    DB_CONFIGURED=false
    return
  fi

  # Interactive (human in terminal)
  echo ""
  echo "  The MCP server needs a PostgreSQL database to connect to."
  echo ""
  echo "  Which would you like?"
  echo ""
  echo "    1) Load a sample database (Northwind — customers, orders, products)"
  echo "       Requires Docker. Great for trying things out."
  echo ""
  echo "    2) Connect to my own PostgreSQL database"
  echo "       You'll provide the connection details."
  echo ""

  local choice
  ask "  Enter 1 or 2: " choice

  case "$choice" in
    1) setup_demo_database ;;
    2) setup_own_database ;;
    *) info "Defaulting to sample database..."; setup_demo_database ;;
  esac
}

# ─── Demo database setup ────────────────────────────────────────────────────

setup_demo_database() {
  if has_docker; then
    start_demo_postgres
    return
  fi

  # Docker not available — offer to install it
  echo ""
  warn "Docker is not installed or not running."
  echo ""
  echo "  The sample database runs in a Docker container."
  echo "  Docker Desktop is free and takes about 5 minutes to install."
  echo ""

  if ! has_tty; then
    echo "DOCKER_NOT_FOUND"
    echo "To install Docker and set up the demo, re-run with: --install-docker"
    echo "To skip the demo and use your own database, re-run with: --own-db --db-host=... --db-port=... --db-name=... --db-user=... --db-pass=..."
    DB_CONFIGURED=false
    return
  fi

  echo "  Would you like me to install Docker for you?"
  echo ""
  echo "    1) Yes, install Docker"
  echo "    2) No, I'll connect to my own database instead"
  echo "    3) No, I'll install Docker myself and re-run this later"
  echo ""

  local choice
  ask "  Enter 1, 2, or 3: " choice

  case "$choice" in
    1) install_docker; start_demo_postgres ;;
    2) setup_own_database ;;
    *)
      echo ""
      echo "  To install Docker Desktop:"
      echo "    https://www.docker.com/products/docker-desktop/"
      echo ""
      echo "  After installing, re-run this command:"
      echo "    curl -fsSL https://raw.githubusercontent.com/AntTheLimey/try-pgedge-mcp-server/main/install.sh | bash"
      echo ""
      DB_CONFIGURED=false
      ;;
  esac
}

# ─── Find a free port ────────────────────────────────────────────────────────

find_free_port() {
  # Try preferred ports in order: 5432, 5433, 5434, 5435, 5436
  for port in 5432 5433 5434 5435 5436; do
    if ! lsof -i ":$port" >/dev/null 2>&1; then
      echo "$port"
      return
    fi
  done
  # Last resort: let the OS pick
  python3 -c "import socket; s=socket.socket(); s.bind(('',0)); print(s.getsockname()[1]); s.close()" 2>/dev/null \
    || echo "0"
}

# ─── Start demo Postgres container ──────────────────────────────────────────

start_demo_postgres() {
  # Check if our demo container is already running
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "pgedge-demo-db"; then
    # Find the port it's mapped to
    local existing_port
    existing_port=$(docker port pgedge-demo-db 5432 2>/dev/null | head -1 | cut -d: -f2)
    if [ -n "$existing_port" ]; then
      ok "Demo database already running on port $existing_port"
      DB_HOST="localhost"; DB_PORT="$existing_port"; DB_NAME="northwind"
      DB_USER="demo"; DB_PASS="demo123"; DB_CONFIGURED=true
      return
    fi
  fi

  # Find a free port
  DEMO_PORT=$(find_free_port)
  if [ "$DEMO_PORT" = "0" ]; then
    warn "Could not find a free port for the demo database."
    DB_CONFIGURED=false
    return
  fi

  if [ "$DEMO_PORT" != "5432" ]; then
    info "Port 5432 is in use (probably an existing Postgres instance)."
    info "Using port $DEMO_PORT for the demo database instead."
  fi

  mkdir -p "$DEMO_DIR"

  # Write docker-compose with placeholder port
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
      - "PGEDGE_HOST_PORT:5432"
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

  # Replace placeholder with actual port
  sed -i.bak "s/PGEDGE_HOST_PORT/$DEMO_PORT/" "$DEMO_DIR/docker-compose.yml"
  rm -f "$DEMO_DIR/docker-compose.yml.bak"

  echo ""
  info "Starting demo Postgres with Northwind sample data on port $DEMO_PORT..."
  info "(first run downloads the image — this may take a minute)"
  echo ""

  docker compose -f "$DEMO_DIR/docker-compose.yml" up -d 2>/dev/null \
    || docker-compose -f "$DEMO_DIR/docker-compose.yml" up -d 2>/dev/null \
    || { warn "Failed to start demo database."; DB_CONFIGURED=false; return; }

  info "Waiting for database to be ready..."
  for i in $(seq 1 24); do
    if docker exec pgedge-demo-db pg_isready -U demo -d northwind >/dev/null 2>&1; then
      ok "Demo database ready (northwind on localhost:$DEMO_PORT)"
      DB_HOST="localhost"; DB_PORT="$DEMO_PORT"; DB_NAME="northwind"
      DB_USER="demo"; DB_PASS="demo123"; DB_CONFIGURED=true
      return
    fi
    sleep 5
  done

  warn "Database is still starting. It may need another minute."
  DB_HOST="localhost"; DB_PORT="$DEMO_PORT"; DB_NAME="northwind"
  DB_USER="demo"; DB_PASS="demo123"; DB_CONFIGURED=true
}

# ─── Own database setup ─────────────────────────────────────────────────────

setup_own_database() {
  # If connection details were provided via flags
  if [ -n "$DB_HOST" ] && [ -n "$DB_NAME" ] && [ -n "$DB_USER" ]; then
    DB_PORT="${DB_PORT:-5432}"
    DB_CONFIGURED=true
    ok "Using database: $DB_NAME on $DB_HOST:$DB_PORT"
    return
  fi

  if ! has_tty; then
    echo ""
    echo "OWN_DATABASE_CHOSEN"
    echo "Re-run with connection details:"
    echo "  --own-db --db-host=HOST --db-port=PORT --db-name=DB --db-user=USER --db-pass=PASS"
    DB_CONFIGURED=false
    return
  fi

  echo ""
  echo "  Enter your PostgreSQL connection details:"
  echo ""

  ask "  Host [localhost]: " DB_HOST
  DB_HOST="${DB_HOST:-localhost}"

  ask "  Port [5432]: " DB_PORT
  DB_PORT="${DB_PORT:-5432}"

  ask "  Database name: " DB_NAME
  [ -z "$DB_NAME" ] && { warn "Database name is required."; DB_CONFIGURED=false; return; }

  ask "  Username: " DB_USER
  [ -z "$DB_USER" ] && { warn "Username is required."; DB_CONFIGURED=false; return; }

  ask "  Password: " DB_PASS

  DB_CONFIGURED=true
  ok "Using database: $DB_NAME on $DB_HOST:$DB_PORT"
}

# ─── Configure Claude Code ──────────────────────────────────────────────────

configure_claude_code() {
  local mcp_json=".mcp.json"
  local binary_path="$BIN_DIR/pgedge-postgres-mcp"

  local new_entry
  new_entry=$(cat << ENTRY
{
  "mcpServers": {
    "pgedge": {
      "command": "$binary_path",
      "env": {
        "PGHOST": "${DB_HOST:-localhost}",
        "PGPORT": "${DB_PORT:-5432}",
        "PGDATABASE": "${DB_NAME:-your_database}",
        "PGUSER": "${DB_USER:-your_user}",
        "PGPASSWORD": "${DB_PASS:-your_password}"
      }
    }
  }
}
ENTRY
)

  # Merge with existing .mcp.json if present
  if [ -f "$mcp_json" ] && command -v python3 &>/dev/null; then
    python3 -c "
import json
existing = json.load(open('$mcp_json'))
new = json.loads('''$new_entry''')
if 'mcpServers' not in existing:
    existing['mcpServers'] = {}
existing['mcpServers'].update(new['mcpServers'])
json.dump(existing, open('$mcp_json', 'w'), indent=2)
print('  ✓  Claude Code: merged pgedge into existing $mcp_json')
" 2>/dev/null && return
  fi

  echo "$new_entry" > "$mcp_json"
  ok "Claude Code: wrote $mcp_json"
}

# ─── Configure Claude Desktop ───────────────────────────────────────────────

configure_claude_desktop() {
  local config_file binary_path="$BIN_DIR/pgedge-postgres-mcp"

  case "$OS" in
    darwin) config_file="$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
    linux)  config_file="$HOME/.config/Claude/claude_desktop_config.json" ;;
    *)      return ;;
  esac

  local config_dir
  config_dir=$(dirname "$config_file")
  if [ ! -d "$config_dir" ]; then
    info "Claude Desktop not detected — skipping config"
    return
  fi

  if command -v python3 &>/dev/null; then
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
        'PGHOST': '${DB_HOST:-localhost}',
        'PGPORT': '${DB_PORT:-5432}',
        'PGDATABASE': '${DB_NAME:-your_database}',
        'PGUSER': '${DB_USER:-your_user}',
        'PGPASSWORD': '${DB_PASS:-your_password}'
    }
}

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
print('  ✓  Claude Desktop: configured (restart Claude Desktop to activate)')
" 2>/dev/null && return
  fi

  # Fallback: write new config
  mkdir -p "$config_dir"
  cat > "$config_file" << DESKTOP
{
  "mcpServers": {
    "pgedge": {
      "command": "$binary_path",
      "env": {
        "PGHOST": "${DB_HOST:-localhost}",
        "PGPORT": "${DB_PORT:-5432}",
        "PGDATABASE": "${DB_NAME:-your_database}",
        "PGUSER": "${DB_USER:-your_user}",
        "PGPASSWORD": "${DB_PASS:-your_password}"
      }
    }
  }
}
DESKTOP
  ok "Claude Desktop: wrote config (restart Claude Desktop to activate)"
}

# ─── Summary ─────────────────────────────────────────────────────────────────

print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Installation complete!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Binary:   $BIN_DIR/pgedge-postgres-mcp"

  if [ "$DB_CONFIGURED" = true ]; then
    echo "  Database: $DB_NAME on $DB_HOST:$DB_PORT ($DB_USER)"
    echo ""
    echo "  Try asking Claude:"
    echo "    \"What tables are in my database?\""
    echo "    \"Show me the top 10 products by sales\""
    echo "    \"Which customers have placed more than 5 orders?\""
  else
    echo "  Database: not yet configured"
    echo ""
    echo "  To configure later, edit:"
    echo "    Claude Code:    .mcp.json"
    echo "    Claude Desktop: ~/Library/Application Support/Claude/claude_desktop_config.json"
  fi

  echo ""
  echo "  Claude Code:    ready — start a new conversation"
  echo "  Claude Desktop: restart the app, then start chatting"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  pgEdge MCP Server — Installer"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  This will install the pgEdge MCP Server so you can"
  echo "  query PostgreSQL databases using natural language"
  echo "  in Claude Code or Claude Desktop."
  echo ""

  DB_CONFIGURED=false

  detect_platform
  get_latest_version
  download_binary

  echo ""
  choose_database

  echo ""
  configure_claude_code
  configure_claude_desktop

  print_summary
}

main "$@"
