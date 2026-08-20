#!/usr/bin/env bash
# Linux Systemd Daemon Script for StreamBDIX + Cloudflare Tunnel

set -e

# Configuration & Paths
PORT=7001
CONFIG_DIR="$HOME/.config/streambdix"
mkdir -p "$CONFIG_DIR"
URL_FILE="$CONFIG_DIR/tunnel_url"
MANIFEST_FILE="$CONFIG_DIR/manifest_url"

# Detect PATH for Node and cloudflared
export PATH="$HOME/.local/bin:$HOME/.nvm/versions/node/$(ls $HOME/.nvm/versions/node 2>/dev/null | tail -n 1)/bin:$PATH"

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Cloudflare Binary Resolution
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
if ! command_exists cloudflared && [ ! -f "$BIN_DIR/cloudflared" ]; then
    echo "[INFO] Downloading cloudflared binary..."
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64|amd64) CF_ARCH="amd64" ;;
        aarch64|arm64) CF_ARCH="arm64" ;;
        armv7l|arm) CF_ARCH="arm" ;;
        i386|i686) CF_ARCH="386" ;;
        *) CF_ARCH="amd64" ;;
    esac
    curl -sSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" -o "$BIN_DIR/cloudflared"
    chmod +x "$BIN_DIR/cloudflared"
fi
CLOUDFLARED_BIN="$(command -v cloudflared || echo "$BIN_DIR/cloudflared")"

# Cleanup handler on exit or systemctl stop
cleanup() {
    echo "[INFO] Stopping StreamBDIX background processes..."
    [ -n "$STREAMBDIX_PID" ] && kill "$STREAMBDIX_PID" 2>/dev/null || true
    [ -n "$TUNNEL_PID" ] && kill "$TUNNEL_PID" 2>/dev/null || true
    rm -f "$LOG_FILE"
    echo "[INFO] Cleanup complete."
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

is_port_open() {
    curl -s http://127.0.0.1:$PORT >/dev/null 2>&1
}

# 2. Start StreamBDIX Server
if is_port_open; then
    echo "[INFO] StreamBDIX server is already running on 127.0.0.1:$PORT."
else
    echo "[INFO] Starting StreamBDIX server on 127.0.0.1:$PORT..."
    npx -y streambdix >/dev/null 2>&1 &
    STREAMBDIX_PID=$!
    
    for i in $(seq 1 15); do
        if is_port_open; then
            echo "[INFO] StreamBDIX server initialized successfully."
            break
        fi
        sleep 1
    done
fi

# 3. Start Cloudflare Tunnel
echo "[INFO] Launching Cloudflare Tunnel..."
LOG_FILE="$(mktemp)"
"$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$PORT" 2> "$LOG_FILE" &
TUNNEL_PID=$!

echo "[INFO] Waiting for Cloudflare Tunnel URL..."
TUNNEL_URL=""
for i in $(seq 1 30); do
    TUNNEL_URL=$(grep -oE 'https://[a-zA-Z0-9]+(-[a-zA-Z0-9]+)+\.trycloudflare\.com' "$LOG_FILE" 2>/dev/null | head -n 1)
    if [ -n "$TUNNEL_URL" ]; then
        break
    fi
    sleep 1
done

if [ -n "$TUNNEL_URL" ]; then
    TUNNEL_URL="$(echo "$TUNNEL_URL" | sed 's/\/*$//')"
    MANIFEST_URL="$TUNNEL_URL/manifest.json"
    
    echo "$TUNNEL_URL" > "$URL_FILE"
    echo "$MANIFEST_URL" > "$MANIFEST_FILE"
    
    echo "====================================================="
    echo "🎉 StreamBDIX Service is Online!"
    echo "🔗 Web URL:      $TUNNEL_URL"
    echo "📦 Manifest URL: $MANIFEST_URL"
    echo "💾 Saved to:     $MANIFEST_FILE"
    echo "====================================================="
    
    wait "$TUNNEL_PID" 2>/dev/null || wait
else
    echo "[ERROR] Failed to obtain Cloudflare Tunnel URL."
    exit 1
fi
