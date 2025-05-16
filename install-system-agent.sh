#!/bin/bash

# --- CONFIG ---
LINUX_BINARY_NAME="system-agent-linux"
WINDOWS_BINARY_NAME="system-agent-windows.exe"

LINUX_DOWNLOAD_URL="https://raw.githubusercontent.com/bharat-creole/script-executable-repo/main/system-agent-linux"
WINDOWS_DOWNLOAD_URL="https://raw.githubusercontent.com/bharat-creole/script-executable-repo/main/system-agent-windows.exe"

LINUX_AGENT_PATH="/usr/local/bin/${LINUX_BINARY_NAME}"
WINDOWS_AGENT_PATH="/c/Program Files/SystemAgent/${WINDOWS_BINARY_NAME}" # For Git Bash or WSL. Windows cmd would be different.

LINUX_USER="$(whoami)"
OS_TYPE="linux"  # default
# --------------

# --- Parse Arguments ---
for arg in "$@"; do
  case $arg in
    --user=*)
      USER_PARAM="${arg#--user=}"
      shift
      ;;
    --server=*)
      SERVER_ID="${arg#--server=}"
      shift
      ;;
    --os=*)
      OS_TYPE="${arg#--os=}"
      shift
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      echo "✅ Usage: $0 --user=YOUR_USER_ID --server=YOUR_SERVER_ID [--os=linux|mac|windows]"
      exit 1
      ;;
  esac
done

# --- Validate Inputs ---
if [[ -z "$USER_PARAM" || -z "$SERVER_ID" ]]; then
  echo "❌ Both --user and --server arguments are required."
  echo "✅ Usage: $0 --user=YOUR_USER_ID --server=YOUR_SERVER_ID [--os=linux|mac|windows]"
  exit 1
fi

# --- Install Based on OS ---
if [[ "$OS_TYPE" == "linux" ]]; then
  echo "🟢 Running installation for Linux..."

  if [[ -f "$LINUX_AGENT_PATH" ]]; then
    echo "🧹 Existing binary found at $LINUX_AGENT_PATH. Removing it..."
    sudo rm -f "$LINUX_AGENT_PATH"
  fi

  echo "📥 Downloading binary from: $LINUX_DOWNLOAD_URL"
  sudo curl -L "$LINUX_DOWNLOAD_URL" -o "$LINUX_AGENT_PATH"
  sudo chmod +x "$LINUX_AGENT_PATH"

  echo "🛠️ Creating systemd service..."
  SERVICE_FILE="/etc/systemd/system/system-agent.service"

  sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=System Agent
After=network.target

[Service]
ExecStart=${LINUX_AGENT_PATH} --user=${USER_PARAM} --server=${SERVER_ID}
Restart=always
User=${LINUX_USER}
Environment=NODE_ENV=production
Environment=NODE_TLS_REJECT_UNAUTHORIZED=0

[Install]
WantedBy=multi-user.target
EOL

  echo "🔄 Reloading systemd and starting service..."
  sudo systemctl daemon-reload
  sudo systemctl enable system-agent
  sudo systemctl restart system-agent

  echo "✅ System Agent installed and running on Linux."

elif [[ "$OS_TYPE" == "windows" ]]; then
  echo "🪟 Running installation for Windows..."

  AGENT_DIR="C:\\Program Files\\SystemAgent"
  AGENT_EXE="C:\\Program Files\\SystemAgent\\system-agent-windows.exe"

  powershell -Command "
    if (Test-Path '$AGENT_EXE') {
      Write-Host '🧹 Removing existing binary at $AGENT_EXE...'
      Remove-Item -Path '$AGENT_EXE' -Force
    }

    if (-Not (Test-Path '$AGENT_DIR')) {
      New-Item -ItemType Directory -Path '$AGENT_DIR'
    }

    Write-Host '📥 Downloading binary from: $WINDOWS_DOWNLOAD_URL'
    Invoke-WebRequest -Uri '$WINDOWS_DOWNLOAD_URL' -OutFile '$AGENT_EXE'

    Write-Host '🛠️ Creating Windows service...'
    sc.exe create "SystemAgent" binPath= "\"$AGENT_EXE\" --user=$USER_PARAM --server=$SERVER_ID" start= auto
    sc.exe start "SystemAgent"

    Write-Host '✅ System Agent installed and running on Windows.'
  "

elif [[ "$OS_TYPE" == "mac" ]]; then
  echo "🍎 macOS installation is not yet implemented. Coming soon."
  exit 1

else
  echo "❌ Unsupported OS type: $OS_TYPE"
  echo "✅ Supported: linux, mac, windows"
  exit 1
fi

