#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="${1:-$(dirname "$SCRIPT_DIR")}"
TARGET="${2:-servers}"  # servers, models, or all

# Source state management
source "$SCRIPT_DIR/state.sh"

# Validate target
case "$TARGET" in
    servers|models|all)
        ;;
    *)
        echo "Usage: /claudio:clean {servers|models|all}"
        echo ""
        echo "Options:"
        echo "  servers  - Remove server installations, keep models"
        echo "  models   - Remove all downloaded models, keep servers"
        echo "  all      - Remove everything (servers + models)"
        exit 1
        ;;
esac

echo "🧹 Cleaning up Claudio: $TARGET"
echo ""

# Stop services first
echo "Stopping any running services..."
"$SCRIPT_DIR/down.sh" "$PLUGIN_DIR"
echo ""

# Get providers
STT_PROVIDER=$(get_provider "stt")
TTS_PROVIDER=$(get_provider "tts")

# Clean each provider
for provider in "$STT_PROVIDER" "$TTS_PROVIDER"; do
    if [ -z "$provider" ]; then
        continue
    fi

    provider_dir="$PLUGIN_DIR/providers/$provider"
    if [ ! -d "$provider_dir" ] || [ ! -f "$provider_dir/clean.sh" ]; then
        continue
    fi

    echo "Cleaning $provider..."
    "$provider_dir/clean.sh" "$TARGET"

    # Remove .installed marker if cleaning servers or all
    if [ "$TARGET" = "servers" ] || [ "$TARGET" = "all" ]; then
        rm -f "$provider_dir/.installed"
    fi
done

echo ""
echo "✅ Cleanup complete!"
echo ""

case "$TARGET" in
    servers)
        echo "Servers removed, models preserved."
        echo "Run /claudio:up to reinstall."
        ;;
    models)
        echo "Models removed, servers preserved."
        echo "Models will redownload on next /claudio:up"
        ;;
    all)
        echo "All components removed."
        echo "Run /claudio:up for fresh installation."
        ;;
esac
