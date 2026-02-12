#!/bin/bash
# Post-create setup for pgEdge MCP Server Codespace demo
# This runs non-interactively during Codespace creation.
set -e

# Copy .env template if .env doesn't exist yet
if [ ! -f .env ]; then
  cp .env.example .env
fi

# Check for API key from Codespace secrets (environment variables)
if [ -n "$PGEDGE_ANTHROPIC_API_KEY" ]; then
  sed -i "s/^PGEDGE_ANTHROPIC_API_KEY=.*/PGEDGE_ANTHROPIC_API_KEY=$PGEDGE_ANTHROPIC_API_KEY/" .env
  echo "✓ Anthropic API key found in Codespace secrets"
elif [ -n "$PGEDGE_OPENAI_API_KEY" ]; then
  sed -i "s/^PGEDGE_OPENAI_API_KEY=.*/PGEDGE_OPENAI_API_KEY=$PGEDGE_OPENAI_API_KEY/" .env
  sed -i "s/^PGEDGE_LLM_PROVIDER=.*/PGEDGE_LLM_PROVIDER=openai/" .env
  sed -i "s/^PGEDGE_LLM_MODEL=.*/PGEDGE_LLM_MODEL=gpt-4o/" .env
  echo "✓ OpenAI API key found in Codespace secrets"
else
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  pgEdge MCP Server Demo — API Key Required"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  No API key detected. To enable natural language queries,"
  echo "  run one of these commands in the terminal:"
  echo ""
  echo "    ./set-key.sh anthropic sk-ant-your-key-here"
  echo "    ./set-key.sh openai sk-your-key-here"
  echo ""
  echo "  Then restart services:"
  echo ""
  echo "    docker compose up -d"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi
