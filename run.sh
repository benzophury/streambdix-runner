#!/usr/bin/env bash
# StreamBDIX & Cloudflare Tunnel Universal Launcher
# OS-Catered process management for Linux, Termux (Android), macOS, etc.

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

# 1. OS & Environment Detection
IS_TERMUX=false
SYSTEM_NAME="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"

if [ -n "$PREFIX" ] && [ -d "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
    IS_TERMUX=true
    OS_TYPE="termux"
    echo -e "${BLUE}📱 System Detected: Android (Termux)${NC}"
    # Set TMPDIR safely for Termux to avoid permission denied on /tmp
    if [ -d "$PREFIX/tmp" ]; then
        export TMPDIR="$PREFIX/tmp"
    fi
elif [ "$SYSTEM_NAME" = "darwin" ]; then
    OS_TYPE="macos"
    echo -e "${BLUE}🍏 System Detected: macOS${NC}"
else
    OS_TYPE="linux"
    echo -e "${BLUE}🐧 System Detected: Standard Linux ($SYSTEM_NAME)${NC}"
fi

# Ensure TMPDIR is set and exists
if [ -z "$TMPDIR" ]; then
    export TMPDIR="/tmp"
fi
mkdir -p "$TMPDIR"

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

# 2. Dependency Resolution per System Type
if ! command_exists node || ! command_exists npx; then
    echo -e "${YELLOW}⚠️ Node.js / npx not found. Attempting installation...${NC}"
    if [ "$OS_TYPE" = "termux" ]; then
        pkg update && pkg install nodejs -y
    elif [ "$OS_TYPE" = "macos" ]; then
        if command_exists brew; then
            brew install node
        else
            echo -e "${RED}Please install Node.js: brew install node${NC}"
            exit 1
        fi
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

# Binary installation directory per OS
if [ "$OS_TYPE" = "termux" ]; then
    BIN_DIR="$PREFIX/bin"
else
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
    export PATH="$BIN_DIR:$PATH"
fi

# 3. Cloudflare Binary Resolution
if ! command_exists cloudflared && [ ! -f "$BIN_DIR/cloudflared" ]; then
    echo -e "${YELLOW}⚠️ cloudflared not found. Downloading for $SYSTEM_NAME-$CF_ARCH...${NC}"
    CF_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-${SYSTEM_NAME}-${CF_ARCH}"
    
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

# 4. Termux Specific DNS & TLS Preparation (proot + ca-certificates)
if [ "$OS_TYPE" = "termux" ]; then
    echo -e "${BLUE}🔧 Setting up Termux network environment (DNS + SSL certificates)...${NC}"
    
    # Ensure proot is installed
    if ! command_exists proot; then
        echo -e "${YELLOW}📦 Installing proot for Termux network compatibility...${NC}"
        pkg install proot -y 2>/dev/null || true
    fi
    
    # Find CA Cert Bundle
    CERT_FILE=""
    for path in \
        "$PREFIX/etc/tls/cert.pem" \
        "$PREFIX/etc/ssl/certs/ca-certificates.crt" \
        "$PREFIX/etc/ca-certificates/extracted/tls-ca-bundle.pem" \
        "$PREFIX/share/ca-certificates/mozilla/cacert.pem"; do
        if [ -f "$path" ]; then
            CERT_FILE="$path"
            break
        fi
    done
    
    if [ -z "$CERT_FILE" ]; then
        echo -e "${YELLOW}📦 Installing ca-certificates...${NC}"
        pkg install ca-certificates -y 2>/dev/null || true
        for path in \
            "$PREFIX/etc/tls/cert.pem" \
            "$PREFIX/etc/ssl/certs/ca-certificates.crt" \
            "$PREFIX/etc/ca-certificates/extracted/tls-ca-bundle.pem" \
            "$PREFIX/share/ca-certificates/mozilla/cacert.pem"; do
            if [ -f "$path" ]; then
                CERT_FILE="$path"
                break
            fi
        done
    fi
    
    if [ -n "$CERT_FILE" ]; then
        export SSL_CERT_FILE="$CERT_FILE"
    fi
    
    # Create resolv.conf with Cloudflare DNS
    RESOLV_FILE="$TMPDIR/resolv.conf"
    cat > "$RESOLV_FILE" <<EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
fi

# Cleanup handler on Ctrl+C / Exit
cleanup() {
    echo -e "\n${YELLOW}🛑 Shutting down processes...${NC}"
    if [ -n "$STREAMBDIX_PID" ]; then
        kill "$STREAMBDIX_PID" 2>/dev/null || true
    fi
    if [ -n "$TUNNEL_PID" ]; then
        kill "$TUNNEL_PID" 2>/dev/null || true
    fi
    [ -n "$RESOLV_FILE" ] && [ -f "$RESOLV_FILE" ] && rm -f "$RESOLV_FILE" 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete. Goodbye!${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# Port check routine
is_port_open() {
    if command_exists curl; then
        curl -s http://127.0.0.1:7001 >/dev/null 2>&1
    elif command_exists lsof; then
        lsof -i :7001 >/dev/null 2>&1
    else
        (exec 3<>/dev/tcp/127.0.0.1/7001) 2>/dev/null
    fi
}

# 5. Process Management for StreamBDIX
PORT=7001
if is_port_open; then
    echo -e "${GREEN}✓ StreamBDIX server is already running on 127.0.0.1:$PORT.${NC}"
else
    echo -e "${BLUE}⚡ Starting StreamBDIX on 127.0.0.1:$PORT...${NC}"
    npx -y streambdix >/dev/null 2>&1 &
    STREAMBDIX_PID=$!
    
    echo -e "${YELLOW}⏳ Waiting for StreamBDIX to initialize...${NC}"
    INIT_TIMEOUT=15
    [ "$OS_TYPE" = "termux" ] && INIT_TIMEOUT=20
    
    for i in $(seq 1 $INIT_TIMEOUT); do
        if is_port_open; then
            echo -e "${GREEN}✓ StreamBDIX started successfully!${NC}"
            break
        fi
        sleep 1
    done
fi

# 6. Cloudflare Tunnel Execution & Log Parsing
echo -e "${BLUE}🌐 Starting Cloudflare Tunnel ($OS_TYPE mode)...${NC}"
LOG_FILE="$(mktemp)"

if [ "$OS_TYPE" = "termux" ]; then
    PROOT_BIN="$(command -v proot || echo "")"
    if [ -n "$PROOT_BIN" ] && [ -f "$RESOLV_FILE" ]; then
        PROOT_ARGS=("-b" "$RESOLV_FILE:/etc/resolv.conf")
        if [ -n "$CERT_FILE" ]; then
            PROOT_ARGS+=("-b" "$CERT_FILE:/etc/ssl/certs/ca-certificates.crt")
        fi
        "$PROOT_BIN" "${PROOT_ARGS[@]}" "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$PORT" 2> "$LOG_FILE" &
    else
        "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$PORT" 2> "$LOG_FILE" &
    fi
    TUNNEL_PID=$!
    MAX_LOOPS=35
else
    # Linux / macOS Mode: Standard stderr redirection
    "$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:$PORT" 2> "$LOG_FILE" &
    TUNNEL_PID=$!
    MAX_LOOPS=25
fi

echo -e "${YELLOW}⏳ Generating public tunnel URL...${NC}"
TUNNEL_URL=""
for i in $(seq 1 $MAX_LOOPS); do
    TUNNEL_URL=$(grep -oE 'https://[a-zA-Z0-9]+(-[a-zA-Z0-9]+)+\.trycloudflare\.com' "$LOG_FILE" 2>/dev/null | head -n 1)
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
    echo -e "${BLUE}💡 Copy the Manifest URL above and paste it into Stremio's Addon search!${NC}"
    echo -e "${BLUE}Press Ctrl+C at any time to stop.${NC}\n"
    
    wait "$TUNNEL_PID" 2>/dev/null || wait
else
    echo -e "${RED}❌ Failed to retrieve Cloudflare Tunnel URL. Check network connection.${NC}"
    exit 1
fi
