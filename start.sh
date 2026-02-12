#!/bin/bash
# Starts the pgEdge MCP Server demo.
# Runs automatically on Codespace start. Also called by set-key.sh.
set -e

# Apply Codespace secrets to .env if present
if [ -n "$PGEDGE_ANTHROPIC_API_KEY" ]; then
  sed -i "s/^PGEDGE_ANTHROPIC_API_KEY=.*/PGEDGE_ANTHROPIC_API_KEY=$PGEDGE_ANTHROPIC_API_KEY/" .env
fi
if [ -n "$PGEDGE_OPENAI_API_KEY" ]; then
  sed -i "s/^PGEDGE_OPENAI_API_KEY=.*/PGEDGE_OPENAI_API_KEY=$PGEDGE_OPENAI_API_KEY/" .env
  sed -i "s/^PGEDGE_LLM_PROVIDER=.*/PGEDGE_LLM_PROVIDER=openai/" .env
  sed -i "s/^PGEDGE_LLM_MODEL=.*/PGEDGE_LLM_MODEL=gpt-4o/" .env
fi

# Check if any API key is configured
ANT_KEY=$(grep '^PGEDGE_ANTHROPIC_API_KEY=' .env | cut -d= -f2)
OAI_KEY=$(grep '^PGEDGE_OPENAI_API_KEY=' .env | cut -d= -f2)

if [ -z "$ANT_KEY" ] && [ -z "$OAI_KEY" ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  pgEdge MCP Server Demo"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  To get started, run:"
  echo ""
  echo "    ./set-key.sh anthropic YOUR_ANTHROPIC_API_KEY"
  echo ""
  echo "  or:"
  echo ""
  echo "    ./set-key.sh openai YOUR_OPENAI_API_KEY"
  echo ""
  echo "  Get a key: https://console.anthropic.com"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
fi

echo ""
echo "Starting pgEdge MCP Server demo..."
echo ""

docker compose up -d

echo ""
echo "Waiting for services to be healthy..."

# Wait for MCP server health (up to 90 seconds)
for i in $(seq 1 18); do
  if docker compose ps --format json 2>/dev/null | grep -q '"Health":"healthy"' 2>/dev/null; then
    break
  fi
  # Fallback: check the health endpoint directly
  if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
    break
  fi
  sleep 5
done

# Build the Web UI URL
if [ -n "$CODESPACE_NAME" ] && [ -n "$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN" ]; then
  WEB_URL="https://${CODESPACE_NAME}-8081.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
else
  WEB_URL="http://localhost:8081"
fi

# Wait for web client too (up to 30 more seconds)
for i in $(seq 1 6); do
  if curl -sf http://localhost:8081/health > /dev/null 2>&1; then
    break
  fi
  sleep 5
done

# Check if web client is up
if curl -sf http://localhost:8081/health > /dev/null 2>&1; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  pgEdge MCP Server Demo is running!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  Web UI:  $WEB_URL"
  echo "  Login:   demo / demo123"
  echo ""
  echo "  Try asking:"
  echo "    What tables are in the database?"
  echo "    Show me the top 10 products by sales"
  echo "    Which customers have placed more than 5 orders?"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
else
  echo ""
  echo "Services are starting. Check progress with: docker compose logs -f"
  echo "Once ready, open: $WEB_URL"
  echo ""
fi
