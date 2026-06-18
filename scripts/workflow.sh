#!/bin/bash
# Path: scripts/workflow.sh
# Usage: source scripts/workflow.sh [plan | code | test | debug | cicd | off | status]

# Read configuration parameters from ~/.bashrc
if [ -f "$HOME/.bashrc" ]; then
  source "$HOME/.bashrc"
fi

MODE=$1
export CONFIG_DIR="$HOME/.config/ai-workflow"
mkdir -p "$CONFIG_DIR"

SETTINGS_FILE="$HOME/projects/token-controller/config/settings.json"

if [ "$MODE" = "off" ]; then
  echo "🛑 Disabling all local token optimization proxies..."
  export RTK_HOOK_ENABLED=false
  export HEADROOM_COMPRESSION_STRATEGY="bypass"
  export MEMSTACK_ACTIVE=false
  export CAVEMAN_OUTPUT=false
  return 0
fi

# Ensure jq is installed to parse json configurations
if ! command -v jq &> /dev/null; then
  echo "❌ Error: 'jq' utility is missing. Run 'sudo apt install jq -y' to continue."
  return 1
fi

# Verify the profile mode exists in the json configuration file
if ! jq -e ".modes.\"$MODE\"" "$SETTINGS_FILE" > /dev/null 2>&1; then
  echo "❌ Error: Profile '$MODE' not found in configurations. Select: plan, code, test, debug, cicd, or off."
  return 1
fi

echo "⚙️ Activating Context Profile: [$MODE]"

# Extract state flags dynamically out of the json schema configuration matrix
export RTK_HOOK_ENABLED=$(jq -r ".modes.\"$MODE\".rtk_hook_enabled" "$SETTINGS_FILE")
export HEADROOM_COMPRESSION_STRATEGY=$(jq -r ".modes.\"$MODE\".headroom_strategy" "$SETTINGS_FILE")
export MEMSTACK_ACTIVE=$(jq -r ".modes.\"$MODE\".memstack_active" "$SETTINGS_FILE")
export CAVEMAN_OUTPUT=$(jq -r ".modes.\"$MODE\".caveman_output" "$SETTINGS_FILE")

echo "   -> RTK Log Hooking: $RTK_HOOK_ENABLED"
echo "   -> Headroom Matrix: $HEADROOM_COMPRESSION_STRATEGY"
echo "   -> MemStack Tracker: $MEMSTACK_ACTIVE"
echo "   -> Caveman Response Syntax: $CAVEMAN_OUTPUT"

if [ -z "$MODE" ]; then
    echo "Error: No argument provided." >&2
    echo "Usage: source scripts/workflow.sh [plan | code | test | debug | cicd | off | status]" >&2
    return 1 2>/dev/null || exit 1
fi

case "$MODE" in
  "plan")
    echo "🗺️ Setting up MODE: Planning & Architecture"
    export RTK_HOOK_ENABLED=false
    export HEADROOM_COMPRESSION_STRATEGY="ast-interfaces-only"
    export MEMSTACK_ACTIVE=true
    export CAVEMAN_OUTPUT=false
    ;;

  "code")
    echo "💻 Setting up MODE: Active Engineering"
    export RTK_HOOK_ENABLED=false
    export HEADROOM_COMPRESSION_STRATEGY="reversible-ccr"
    export MEMSTACK_ACTIVE=true
    export CAVEMAN_OUTPUT=false
    ;;

  "test")
    echo "🧪 Setting up MODE: Automated Test Routines"
    export RTK_HOOK_ENABLED=true
    export HEADROOM_COMPRESSION_STRATEGY="aggressive-logs"
    export MEMSTACK_ACTIVE=false
    export CAVEMAN_OUTPUT=true
    ;;

  "debug")
    echo "🪲 Setting up MODE: Precise Debugging & Fault Isolation"
    export RTK_HOOK_ENABLED=true
    export HEADROOM_COMPRESSION_STRATEGY="safety-first-lossless"
    export MEMSTACK_ACTIVE=true
    export CAVEMAN_OUTPUT=false
    ;;

  "cicd")
    echo "📦 Setting up MODE: Pipeline Build & Environment Diagnostics"
    export RTK_HOOK_ENABLED=true
    export HEADROOM_COMPRESSION_STRATEGY="strip-boilerplate"
    export MEMSTACK_ACTIVE=false
    export CAVEMAN_OUTPUT=true
    ;;

  "off")
    echo "🛑 Disabling all local token optimization proxies"
    export RTK_HOOK_ENABLED=false
    export HEADROOM_COMPRESSION_STRATEGY="bypass"
    export MEMSTACK_ACTIVE=false
    export CAVEMAN_OUTPUT=false
    ;;

  "status")
    echo "Current Token Optimization Status:"
    echo "  RTK_HOOK_ENABLED=$RTK_HOOK_ENABLED"
    echo "  HEADROOM_COMPRESSION_STRATEGY=$HEADROOM_COMPRESSION_STRATEGY"
    echo "  MEMSTACK_ACTIVE=$MEMSTACK_ACTIVE"
    echo "  CAVEMAN_OUTPUT=$CAVEMAN_OUTPUT"
    return 0 2>/dev/null || exit 0
    ;;

  *)
    echo "Error: Invalid mode '$MODE' selected. Use: plan, code, test, debug, cicd, off, or status." >&2
    return 1 2>/dev/null || exit 1
    ;;
esac

# Persist environment variables down to a temporary environment cache for verification
echo "export RTK_HOOK_ENABLED=$RTK_HOOK_ENABLED" > "$CONFIG_DIR/active_mode.env"
echo "export HEADROOM_COMPRESSION_STRATEGY=$HEADROOM_COMPRESSION_STRATEGY" >> "$CONFIG_DIR/active_mode.env"
echo "export MEMSTACK_ACTIVE=$MEMSTACK_ACTIVE" >> "$CONFIG_DIR/active_mode.env"
echo "export CAVEMAN_OUTPUT=$CAVEMAN_OUTPUT" >> "$CONFIG_DIR/active_mode.env"