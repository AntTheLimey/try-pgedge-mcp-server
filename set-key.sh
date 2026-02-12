#!/bin/bash
# Set your LLM API key for the pgEdge MCP Server demo.
#
# Usage:
#   ./set-key.sh anthropic sk-ant-your-key-here
#   ./set-key.sh openai sk-your-key-here
set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: ./set-key.sh <provider> <api-key>"
  echo ""
  echo "  provider: anthropic or openai"
  echo "  api-key:  your API key"
  echo ""
  echo "Examples:"
  echo "  ./set-key.sh anthropic sk-ant-abc123..."
  echo "  ./set-key.sh openai sk-proj-abc123..."
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
    echo "✓ Anthropic API key saved"
    ;;
  openai)
    sed -i "s/^PGEDGE_OPENAI_API_KEY=.*/PGEDGE_OPENAI_API_KEY=$KEY/" .env
    sed -i "s/^PGEDGE_LLM_PROVIDER=.*/PGEDGE_LLM_PROVIDER=openai/" .env
    sed -i "s/^PGEDGE_LLM_MODEL=.*/PGEDGE_LLM_MODEL=gpt-4o/" .env
    echo "✓ OpenAI API key saved"
    ;;
  *)
    echo "Unknown provider: $PROVIDER"
    echo "Use 'anthropic' or 'openai'"
    exit 1
    ;;
esac

echo ""
echo "Now restart services:"
echo "  docker compose down && docker compose up -d"
