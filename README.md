# 🚀 StreamBDIX Universal One-Key Runner

Universal one-liner installer and runner for [StreamBDIX](https://github.com/Corpse00/StreamBDIX) with **Cloudflare Tunnel**.

Runs seamlessly on **Linux**, **macOS**, and **Android (Termux)**!

---

## ⚡ One-Line Quick Start (Termux / Linux / macOS)

Run this command in your terminal:

```bash
curl -sSL https://tinyurl.com/streambdix-run | bash
```

Or raw GitHub link:

```bash
curl -sSL https://raw.githubusercontent.com/benzophury/streambdix-runner/main/run.sh | bash
```

---

## 🐧 Linux Systemd Service Setup (Run as background daemon on boot)

To set up StreamBDIX as a persistent `systemd` user service on Linux (no browser dependency, auto-restarts):

```bash
cd ~/Documents/StremioNuviaProjects/streambdix-runner # or your cloned directory
./setup_linux_service.sh
```

### Useful Systemd Commands:
- **View service status**: `systemctl --user status streambdix`
- **View live logs & tunnel URL**: `journalctl --user -u streambdix -f`
- **Read current Stremio Manifest URL**: `cat ~/.config/streambdix/manifest_url`
- **Stop service**: `systemctl --user stop streambdix`
- **Restart service**: `systemctl --user restart streambdix`

---

## 🔍 Features

- 📱 **Termux & Linux Native**: Automatically handles Android Termux network quirks (DNS + CA certificates via `proot`).
- 📦 **Auto Dependency Setup**: Installs Node.js / `npx` and downloads `cloudflared` for your CPU architecture (`amd64`, `arm64`, `arm`).
- 🌐 **Cloudflare Tunnel**: Automatically generates a public HTTPS URL (`*.trycloudflare.com`) to connect your Stremio app anywhere.
- ⚙️ **Systemd Daemon Mode**: Run as a background service on Linux without holding a terminal window open.
