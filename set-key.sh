#!/bin/bash
# One-step API key setup for the pgEdge MCP Server demo.
#
# Usage:
#   ./set-key.sh anthropic sk-ant-your-key-here
#   ./set-key.sh openai sk-your-key-here
set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo ""
  echo "Usage: ./set-key.sh <provider> <api-key>"
  echo ""
  echo "  ./set-key.sh anthropic sk-ant-abc123..."
  echo "  ./set-key.sh openai sk-proj-abc123..."
  echo ""
  exit 1
fi

PROVIDER="$1"
KEY="$2"

if [ ! -f .env ]; then
  cp .env.example .env
fi

case "$PROVIDER" in
  anthropic)
    sed -i "s/^PGEDGE_ANTHROPIC_API_KEY=.*/PGEDGE_ANTHROPIC_API_KEY=$KEY/" .env
    sed -i "s/^PGEDGE_LLM_PROVIDER=.*/PGEDGE_LLM_PROVIDER=anthropic/" .env
    sed -i "s/^PGEDGE_LLM_MODEL=.*/PGEDGE_LLM_MODEL=claude-sonnet-4-5/" .env
    ;;
  openai)
    sed -i "s/^PGEDGE_OPENAI_API_KEY=.*/PGEDGE_OPENAI_API_KEY=$KEY/" .env
    sed -i "s/^PGEDGE_LLM_PROVIDER=.*/PGEDGE_LLM_PROVIDER=openai/" .env
    sed -i "s/^PGEDGE_LLM_MODEL=.*/PGEDGE_LLM_MODEL=gpt-4o/" .env
    ;;
  *)
    echo "Unknown provider: $PROVIDER (use 'anthropic' or 'openai')"
    exit 1
    ;;
esac

# Start (or restart) services
docker compose down 2>/dev/null || true
exec bash start.sh
