# 🚀 StreamBDIX Universal One-Key Runner

Universal one-liner installer and runner for [StreamBDIX](https://github.com/Corpse00/StreamBDIX) with **Cloudflare Tunnel**.

Runs seamlessly on **Linux**, **macOS**, and **Android (Termux)**!

---

## ⚡ One-Line Quick Start

Run this command in your terminal (Linux, macOS, or Termux):

```bash
curl -sSL https://raw.githubusercontent.com/benzophury/streambdix-runner/main/run.sh | bash
```

---

## 🔍 Features

- 📱 **Termux & Linux Native**: Automatically detects Android Termux vs Linux/macOS.
- 📦 **Auto Dependency Setup**: Installs Node.js / `npx` (if missing on Termux) and downloads the correct `cloudflared` binary for your CPU architecture (`amd64`, `arm64`, `arm`).
- 🌐 **Cloudflare Tunnel**: Automatically generates a public HTTPS URL (`*.trycloudflare.com`) to connect your Stremio app anywhere.
- 🧹 **Clean Shutdown**: Safely stops background processes on `Ctrl+C`.

---

## 🛠️ Termux Setup Guide (Android)

1. Open **Termux**.
2. Run:
   ```bash
   pkg update && pkg install curl -y
   curl -sSL https://raw.githubusercontent.com/benzophury/streambdix-runner/main/run.sh | bash
   ```
3. Copy the generated `https://xxxx.trycloudflare.com/manifest.json` link and paste it into **Stremio**!
