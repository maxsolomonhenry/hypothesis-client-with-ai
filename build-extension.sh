#!/usr/bin/env bash
#
# Build the Hypothesis client and browser extension in one step.
# Assumes the extension repo is a sibling directory of this (client) repo.
#
# Usage:
#   ./build-extension.sh          # Full build (client + extension)
#   ./build-extension.sh --watch  # Watch mode: rebuilds on client changes
#   ./build-extension.sh --ext    # Extension only (skip client build)
#   ./build-extension.sh --setup  # First-time setup: fix portal path + yarn install
#
# After building, reload the extension in Chrome:
#   chrome://extensions/ -> click reload on the unpacked extension

set -euo pipefail

# Resolve paths relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$SCRIPT_DIR"
PARENT_DIR="$(dirname "$CLIENT_DIR")"

# Look for the extension repo as a sibling directory
EXT_DIR_NAME="hypothesis-browser-extension-with-AI"
EXT_DIR="$PARENT_DIR/$EXT_DIR_NAME"

if [[ ! -d "$EXT_DIR" ]]; then
    echo "Extension repo not found at: $EXT_DIR"
    echo ""
    echo "Expected directory layout:"
    echo "  some-parent/"
    echo "    hypothesis-client-with-ai/       (this repo)"
    echo "    $EXT_DIR_NAME/   (extension repo)"
    echo ""
    read -rp "Enter path to the extension repo (or press Enter to abort): " custom_path
    if [[ -z "$custom_path" ]]; then
        echo "Aborted."
        exit 1
    fi
    EXT_DIR="$(cd "$custom_path" && pwd)"
    if [[ ! -f "$EXT_DIR/package.json" ]]; then
        echo "Error: No package.json found at $EXT_DIR"
        exit 1
    fi
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()   { echo -e "${GREEN}[build]${NC} $*"; }
warn()  { echo -e "${YELLOW}[build]${NC} $*"; }
error() { echo -e "${RED}[build]${NC} $*" >&2; }

setup() {
    log "Setting up portal resolution..."
    log "Client dir: $CLIENT_DIR"
    log "Extension dir: $EXT_DIR"

    # Check current resolutions in the extension's package.json
    if grep -q '"hypothesis"' "$EXT_DIR/package.json"; then
        # Replace any existing portal: path for "hypothesis" with the correct one
        # Use node for reliable JSON manipulation
        node -e "
            const fs = require('fs');
            const pkg = JSON.parse(fs.readFileSync('$EXT_DIR/package.json', 'utf8'));
            pkg.resolutions = pkg.resolutions || {};
            pkg.resolutions['hypothesis'] = 'portal:$CLIENT_DIR';
            // Remove stale keys that pointed to old paths
            for (const key of Object.keys(pkg.resolutions)) {
                if (key !== 'hypothesis' && pkg.resolutions[key].includes('hypothesis-client')) {
                    delete pkg.resolutions[key];
                }
            }
            fs.writeFileSync('$EXT_DIR/package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
        log "Updated portal resolution in extension package.json"
    fi

    log "Installing client dependencies..."
    (cd "$CLIENT_DIR" && yarn install)

    log "Installing extension dependencies..."
    (cd "$EXT_DIR" && yarn install)

    log "Setup complete!"
}

build_client() {
    log "Building client..."
    (cd "$CLIENT_DIR" && make build)
    log "Client build complete."
}

fix_manifest_version() {
    local manifest="$EXT_DIR/build/manifest.json"
    if [[ -f "$manifest" ]] && grep -q '"null.null"' "$manifest"; then
        log "Fixing manifest version (git tags not available)..."
        node -e "
            const fs = require('fs');
            const m = JSON.parse(fs.readFileSync('$manifest', 'utf8'));
            m.version = '0.0.1';
            m.version_name = 'dev';
            fs.writeFileSync('$manifest', JSON.stringify(m, null, 2) + '\n');
        "
    fi
}

build_extension() {
    log "Building extension..."
    cp "$CLIENT_DIR/extension-settings.json" "$EXT_DIR/settings/chrome-dev-remote.json"
    (cd "$EXT_DIR" && make build SETTINGS_FILE=settings/chrome-dev-remote.json)
    fix_manifest_version
    echo ""
    log "Done! Reload the extension in Chrome:"
    log "  1. Go to chrome://extensions/"
    log "  2. Click the reload icon on the Hypothesis extension"
    log "  (Unpacked dir: $EXT_DIR/build/)"
}

watch_mode() {
    log "Starting watch mode..."
    log "Client dev server will auto-rebuild on changes."
    log "When you're ready to test in Chrome, press Ctrl+C then run:"
    log "  ./build-extension.sh --ext"
    echo ""
    (cd "$CLIENT_DIR" && make dev)
}

# --- Main ---

case "${1:-}" in
    --setup|-s)
        setup
        ;;
    --watch|-w)
        watch_mode
        ;;
    --ext|-e)
        build_extension
        ;;
    --help|-h)
        echo "Usage: ./build-extension.sh [OPTION]"
        echo ""
        echo "  (no args)   Full build: client + extension"
        echo "  --setup     First-time setup: fix portal path + yarn install"
        echo "  --watch     Run client in watch/dev mode (auto-rebuild on changes)"
        echo "  --ext       Build extension only (assumes client is already built)"
        echo "  --help      Show this help"
        echo ""
        echo "Client dir:    $CLIENT_DIR"
        echo "Extension dir: $EXT_DIR"
        ;;
    *)
        build_client
        build_extension
        ;;
esac
