#!/usr/bin/env bash
# Installer script for StreamBDIX Systemd User Service

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START_SCRIPT="$SCRIPT_DIR/start_linux.sh"
chmod +x "$START_SCRIPT"

SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$SYSTEMD_DIR/streambdix.service"

mkdir -p "$SYSTEMD_DIR"

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}  ⚙️ StreamBDIX Systemd Service Setup                ${NC}"
echo -e "${CYAN}=====================================================${NC}"

PATH_ENV="$PATH"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=StreamBDIX & Cloudflare Tunnel Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$START_SCRIPT
Restart=always
RestartSec=5
Environment=PATH=$PATH_ENV

[Install]
WantedBy=default.target
EOF

echo -e "${GREEN}✓ Created systemd unit file at $SERVICE_FILE${NC}"

if command -v systemctl >/dev/null 2>&1; then
    echo -e "${BLUE}⚡ Reloading systemd user daemon...${NC}"
    systemctl --user daemon-reload 2>/dev/null || true
    
    echo -e "${BLUE}🚀 Enabling and starting streambdix service...${NC}"
    systemctl --user enable --now streambdix.service 2>/dev/null || true
    
    if command -v loginctl >/dev/null 2>&1; then
        loginctl enable-linger "$USER" 2>/dev/null || true
    fi
    
    echo -e "\n${CYAN}=====================================================${NC}"
    echo -e "${GREEN}🎉 StreamBDIX Systemd Service Installed & Started!${NC}"
    echo -e "${CYAN}=====================================================${NC}"
    echo -e "${YELLOW}Useful Service Commands:${NC}"
    echo -e "  • View status:      ${CYAN}systemctl --user status streambdix${NC}"
    echo -e "  • View live logs:   ${CYAN}journalctl --user -u streambdix -f${NC}"
    echo -e "  • Stop service:     ${CYAN}systemctl --user stop streambdix${NC}"
    echo -e "  • Restart service:  ${CYAN}systemctl --user restart streambdix${NC}"
    echo -e "  • Read Manifest:    ${CYAN}cat ~/.config/streambdix/manifest_url${NC}"
    echo -e "${CYAN}=====================================================${NC}"
else
    echo -e "${YELLOW}⚠️ systemctl command not found. Run $START_SCRIPT directly.${NC}"
fi
