#!/bin/bash
# Post-create setup for pgEdge MCP Server Codespace demo
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
  echo "✓ OpenAI API key found in Codespace secrets"
else
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  pgEdge MCP Server Demo — API Key Setup"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "You need an Anthropic or OpenAI API key to power"
  echo "natural language queries."
  echo ""
  read -p "Anthropic API key (or Enter to skip): " -s ANT_KEY
  echo ""
  if [ -n "$ANT_KEY" ]; then
    sed -i "s/^PGEDGE_ANTHROPIC_API_KEY=.*/PGEDGE_ANTHROPIC_API_KEY=$ANT_KEY/" .env
    echo "✓ Anthropic key saved"
  else
    read -p "OpenAI API key (or Enter to skip): " -s OAI_KEY
    echo ""
    if [ -n "$OAI_KEY" ]; then
      sed -i "s/^PGEDGE_OPENAI_API_KEY=.*/PGEDGE_OPENAI_API_KEY=$OAI_KEY/" .env
      sed -i "s/^PGEDGE_LLM_PROVIDER=.*/PGEDGE_LLM_PROVIDER=openai/" .env
      sed -i "s/^PGEDGE_LLM_MODEL=.*/PGEDGE_LLM_MODEL=gpt-4o/" .env
      echo "✓ OpenAI key saved"
    else
      echo ""
      echo "⚠  No API key provided."
      echo "   Edit .env and add your key, then run:"
      echo "   docker compose up -d"
      echo ""
    fi
  fi
fi
