#!/bin/bash
# ================================================================
#  Device42 Linux agent installation
#  Author: mohdyazidms
#  Version: v1.0
#  Date: 2025-10-07
# ================================================================
# ---- CONFIG ----
BASE_URL="https://github.com/mohdyazidms/d42/tree/main"
LINUX_AGENT="d42_linuxagent_x64"
FREEBSD_AGENT=""
INSTALL_DIR="/opt/device42"
LOGFILE="/var/log/d42_agent_install.log"
# ---- INITIAL CHECK ----
mkdir -p "$(dirname "$LOGFILE")"
exec > >(tee -a "$LOGFILE") 2>&1
echo "=============================================================="
echo " Device42 Agent Installer"
echo "=============================================================="
echo "Date: $(date)"
echo "Log  : $LOGFILE"
echo
# ---- ROOT CHECK ----
if [ "$EUID" -ne 0 ]; then
  echo " Please run this script as root (sudo)."
  exit 1
fi
# ---- OS DETECTION ----
echo "Detecting OS type..."
OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "$OS_TYPE" == *"freebsd"* ]]; then
    AGENT_FILE="$FREEBSD_AGENT"
    echo " Detected OS: FreeBSD"
else
    AGENT_FILE="$LINUX_AGENT"
    echo " Detected OS: Linux"
fi
echo "Agent selected: $AGENT_FILE"
echo
# ---- PREPARE INSTALL DIR ----
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit 1
# ---- DOWNLOAD AGENT ----
AGENT_URL="$BASE_URL/$AGENT_FILE"
echo "Downloading agent from: $AGENT_URL"
if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$AGENT_FILE" "$AGENT_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$AGENT_FILE" "$AGENT_URL"
else
    echo " Neither curl nor wget found. Please install one and rerun."
    exit 1
fi
if [ ! -f "$AGENT_FILE" ]; then
    echo " Download failed. File not found after download attempt."
    exit 1
fi
chmod +x "$AGENT_FILE"
echo " Download completed and file made executable."
echo
# ---- USER CONFIRMATION ----
read -rp "Proceed with Device42 Agent installation? (Y/N): " choice
case "$choice" in
  [Yy]* ) echo "Installing...";;
  * ) echo "Installation aborted by user."; exit 0;;
esac
# ---- INSTALLATION ----
echo "Running installation for: $AGENT_FILE"
if [[ "$OS_TYPE" == *"freebsd"* ]]; then
    ./"$AGENT_FILE"
else
    ./"$AGENT_FILE"
fi
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo " Device42 Agent installation completed successfully."
else
    echo " Installation process exited with code $EXIT_CODE. Please review logs."
fi
echo
# ---- CLEANUP ----
read -rp "Remove installer file after installation? (Y/N): " cleanup
if [[ "$cleanup" =~ ^[Yy]$ ]]; then
    rm -f "$INSTALL_DIR/$AGENT_FILE"
    echo " Installer file removed."
else
    echo " Installer file retained at: $INSTALL_DIR/$AGENT_FILE"
fi
echo
echo "=============================================================="
echo " Installation completed. Logs stored at: $LOGFILE"
echo "=============================================================="
exit 0
