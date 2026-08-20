#!/usr/bin/env bash
# StreamBDIX & Cloudflare Tunnel Universal Launcher
# Compatible with Linux, Termux (Android), macOS, etc.

set -e

# Terminal Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}  🚀 StreamBDIX + Cloudflare Tunnel Auto-Launcher  ${NC}"
echo -e "${CYAN}=====================================================${NC}"

# 1. Detect Termux / Linux Environment
IS_TERMUX=false
if [ -n "$PREFIX" ] && [ -d "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
    IS_TERMUX=true
    echo -e "${BLUE}ℹ️ Environment: Termux (Android)${NC}"
else
    echo -e "${BLUE}ℹ️ Environment: Standard Linux / Unix System${NC}"
fi

# 2. Detect OS & Architecture
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

case "$ARCH" in
    x86_64|amd64)
        CF_ARCH="amd64"
        ;;
    aarch64|arm64)
        CF_ARCH="arm64"
        ;;
    armv7l|armv6l|arm)
        CF_ARCH="arm"
        ;;
    i386|i686)
        CF_ARCH="386"
        ;;
    *)
        echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 3. Check for Node.js & npx
if ! command_exists node || ! command_exists npx; then
    echo -e "${YELLOW}⚠️ Node.js / npx not found. Attempting installation...${NC}"
    if [ "$IS_TERMUX" = true ]; then
        pkg update && pkg install nodejs -y
    elif command_exists apt-get; then
        echo -e "${RED}Please install Node.js: sudo apt install nodejs npm -y${NC}"
        exit 1
    elif command_exists pacman; then
        echo -e "${RED}Please install Node.js: sudo pacman -S nodejs npm${NC}"
        exit 1
    elif command_exists dnf; then
        echo -e "${RED}Please install Node.js: sudo dnf install nodejs npm${NC}"
        exit 1
    else
        echo -e "${RED}❌ Please install Node.js and npx manually to continue.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Node.js $(node -v) & npx detected${NC}"

# Determine installation directory for binaries
if [ "$IS_TERMUX" = true ]; then
    BIN_DIR="$PREFIX/bin"
else
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
    export PATH="$BIN_DIR:$PATH"
fi

# 4. Ensure cloudflared is installed
if ! command_exists cloudflared && [ ! -f "$BIN_DIR/cloudflared" ]; then
    echo -e "${YELLOW}⚠️ cloudflared not found. Downloading for $OS-$CF_ARCH...${NC}"
    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${OS}-${CF_ARCH}"
    
    if command_exists curl; then
        curl -sSL "$CF_URL" -o "$BIN_DIR/cloudflared"
    elif command_exists wget; then
        wget -q "$CF_URL" -O "$BIN_DIR/cloudflared"
    else
        echo -e "${RED}❌ Neither curl nor wget is available.${NC}"
        exit 1
    fi
    chmod +x "$BIN_DIR/cloudflared"
fi
CLOUDFLARED_BIN="$(command -v cloudflared || echo "$BIN_DIR/cloudflared")"
echo -e "${GREEN}✓ cloudflared detected at $CLOUDFLARED_BIN${NC}"

# Cleanup handler on Ctrl+C / Exit
cleanup() {
    echo -e "\n${YELLOW}🛑 Shutting down processes...${NC}"
    if [ -n "$STREAMBDIX_PID" ]; then
        kill "$STREAMBDIX_PID" 2>/dev/null || true
    fi
    if [ -n "$TUNNEL_PID" ]; then
        kill "$TUNNEL_PID" 2>/dev/null || true
    fi
    echo -e "${GREEN}✓ Cleanup complete. Goodbye!${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Function to check if port 7001 is listening
is_port_open() {
    if command_exists curl; then
        curl -s http://127.0.0.1:7001 >/dev/null 2>&1
    elif command_exists lsof; then
        lsof -i :7001 >/dev/null 2>&1
    else
        (exec 3<>/dev/tcp/127.0.0.1/7001) 2>/dev/null
    fi
}

# 5. Start StreamBDIX if not already running
PORT=7001
if is_port_open; then
    echo -e "${GREEN}✓ StreamBDIX server is already running on 127.0.0.1:$PORT.${NC}"
else
    echo -e "${BLUE}⚡ Starting StreamBDIX on 127.0.0.1:$PORT...${NC}"
    npx -y streambdix >/dev/null 2>&1 &
    STREAMBDIX_PID=$!
    
    # Wait for StreamBDIX to respond on port 7001 (up to 15s)
    echo -e "${YELLOW}⏳ Waiting for StreamBDIX to initialize...${NC}"
    for i in {1..15}; do
        if is_port_open; then
            echo -e "${GREEN}✓ StreamBDIX started successfully!${NC}"
            break
        fi
        sleep 1
    done
fi

# 6. Start Cloudflare Tunnel pointing to 127.0.0.1:7001
echo -e "${BLUE}🌐 Starting Cloudflare Tunnel...${NC}"
LOG_FILE="$(mktemp)"
"$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$PORT" > "$LOG_FILE" 2>&1 &
TUNNEL_PID=$!

echo -e "${YELLOW}⏳ Generating public tunnel URL...${NC}"
TUNNEL_URL=""
for i in {1..25}; do
    # Target the exact banner line after "Your quick Tunnel has been created" and filter out api.* subdomains
    TUNNEL_URL=$(grep -A 2 "Your quick Tunnel has been created" "$LOG_FILE" 2>/dev/null | grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' | grep -v 'api\.' | tr -d '\r' | head -n 1)
    if [ -z "$TUNNEL_URL" ]; then
        TUNNEL_URL=$(grep -oE 'https://[a-zA-Z0-9-]+\.trycloudflare\.com' "$LOG_FILE" 2>/dev/null | grep -v 'api\.' | tr -d '\r' | head -n 1)
    fi
    if [ -n "$TUNNEL_URL" ]; then
        break
    fi
    sleep 1
done

rm -f "$LOG_FILE"

if [ -n "$TUNNEL_URL" ]; then
    # Strip trailing slashes
    TUNNEL_URL="$(echo "$TUNNEL_URL" | sed 's/\/*$//')"
    
    echo -e "\n${CYAN}=====================================================${NC}"
    echo -e "${GREEN}🎉 SUCCESS! StreamBDIX Tunnel is Live!${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${YELLOW}🔗 Web Interface URL:${NC}   $TUNNEL_URL"
    echo -e "${YELLOW}📦 Stremio Manifest URL:${NC} $TUNNEL_URL/manifest.json"
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${BLUE}💡 Copy the Manifest URL above and paste it into Stremio's Addon search!${NC}"
    echo -e "${BLUE}Press Ctrl+C at any time to stop.${NC}\n"
    
    wait "$TUNNEL_PID" 2>/dev/null || wait
else
    echo -e "${RED}❌ Failed to retrieve Cloudflare Tunnel URL. Check network connection.${NC}"
    exit 1
fi
