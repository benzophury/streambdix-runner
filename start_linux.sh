#!/usr/bin/env bash
# Local Linux Launcher for StreamBDIX + Cloudflare Tunnel + Firefox Nightly

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN} 🐧 StreamBDIX Linux Launcher + Firefox Nightly    ${NC}"
echo -e "${CYAN}=====================================================${NC}"

PORT=7001
CLOUDFLARED_BIN="$(command -v cloudflared || echo "$HOME/.local/bin/cloudflared")"

# Function to check if port is listening
is_port_open() {
    curl -s http://127.0.0.1:$PORT >/dev/null 2>&1
}

# 1. Start StreamBDIX if not running
if is_port_open; then
    echo -e "${GREEN}✓ StreamBDIX server is already running on 127.0.0.1:$PORT.${NC}"
else
    echo -e "${BLUE}⚡ Starting StreamBDIX on 127.0.0.1:$PORT...${NC}"
    npx -y streambdix >/dev/null 2>&1 &
    STREAMBDIX_PID=$!
    
    echo -e "${YELLOW}⏳ Waiting for StreamBDIX to initialize...${NC}"
    for i in {1..15}; do
        if is_port_open; then
            echo -e "${GREEN}✓ StreamBDIX started successfully!${NC}"
            break
        fi
        sleep 1
    done
fi

# Cleanup handler on exit or Ctrl+C
cleanup() {
    echo -e "\n${YELLOW}🛑 Shutting down background processes...${NC}"
    [ -n "$STREAMBDIX_PID" ] && kill "$STREAMBDIX_PID" 2>/dev/null || true
    [ -n "$TUNNEL_PID" ] && kill "$TUNNEL_PID" 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete. Goodbye!${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# 2. Start Cloudflare Tunnel
echo -e "${BLUE}🌐 Starting Cloudflare Tunnel...${NC}"
LOG_FILE="$(mktemp)"
"$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$PORT" --logfile "$LOG_FILE" >/dev/null 2>&1 &
TUNNEL_PID=$!

echo -e "${YELLOW}⏳ Generating public tunnel URL...${NC}"
TUNNEL_URL=""
for i in {1..25}; do
    TUNNEL_URL=$(grep -i "trycloudflare.com" "$LOG_FILE" 2>/dev/null | grep -v "api\.trycloudflare\.com" | grep -oE 'https://[^[:space:]|\"]+\.trycloudflare\.com' | tr -d '\r' | head -n 1)
    if [ -n "$TUNNEL_URL" ]; then
        break
    fi
    sleep 1
done
rm -f "$LOG_FILE"

if [ -n "$TUNNEL_URL" ]; then
    TUNNEL_URL="$(echo "$TUNNEL_URL" | sed 's/\/*$//')"
    
    echo -e "\n${CYAN}=====================================================${NC}"
    echo -e "${GREEN}🎉 SUCCESS! StreamBDIX Tunnel is Live!${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${YELLOW}🔗 Web Interface URL:${NC}   $TUNNEL_URL"
    echo -e "${YELLOW}📦 Stremio Manifest URL:${NC} $TUNNEL_URL/manifest.json"
    echo -e "${CYAN}=====================================================${NC}"
    
    # 3. Tie in with Firefox Nightly
    FIREFOX_BIN="$(command -v firefox-nightly || command -v firefox || echo "")"
    if [ -n "$FIREFOX_BIN" ]; then
        echo -e "${BLUE}🦊 Opening Firefox Nightly ($FIREFOX_BIN) -> $TUNNEL_URL${NC}"
        "$FIREFOX_BIN" "$TUNNEL_URL" >/dev/null 2>&1 &
    else
        echo -e "${YELLOW}⚠️ Firefox Nightly binary not found. Please open $TUNNEL_URL manually in your browser.${NC}"
    fi
    
    echo -e "${BLUE}Press Ctrl+C at any time to stop.${NC}\n"
    wait "$TUNNEL_PID" 2>/dev/null || wait
else
    echo -e "${RED}❌ Failed to retrieve Cloudflare Tunnel URL.${NC}"
    exit 1
fi
