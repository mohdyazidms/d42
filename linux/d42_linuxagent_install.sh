#!/bin/bash
# Device42 Agent Installer Script (Full Scan Version)
# Compatible with CentOS 7, AlmaLinux 8 & 9
# Must be run as root

set -e

DOWNLOAD_URL="https://github.com/mohdyazidms/d42/releases/download/v1.4/d42_linuxagent_x64"
INSTALL_DIR="/opt/device42"
AGENT_FILE="d42_linuxagent_x64"
AGENT_PATH="$INSTALL_DIR/$AGENT_FILE"
CRON_JOB="/etc/cron.d/device42_agent"
LOG_FILE="/var/log/device42_install.log"

# --- Function to detect OS version ---
detect_os() {
    if [ -f /etc/centos-release ]; then
        OS="CentOS"
        VERSION=$(rpm -E %{rhel})
    elif [ -f /etc/almalinux-release ]; then
        OS="AlmaLinux"
        VERSION=$(rpm -E %{rhel})
    else
        echo "Unsupported OS. Only CentOS 7 and AlmaLinux 8/9 are supported."
        exit 1
    fi
    echo "Detected OS: $OS $VERSION"
}

# --- Ensure script runs as root ---
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# --- Detect OS ---
detect_os

# --- Prepare directory ---
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# --- Download agent binary using curl or wget ---
echo "Downloading Device42 Agent from $DOWNLOAD_URL ..."
if command -v curl >/dev/null 2>&1; then
    curl -L -o "$AGENT_FILE" "$DOWNLOAD_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$AGENT_FILE" "$DOWNLOAD_URL"
else
    echo "Error: Neither curl nor wget is installed. Please install one and re-run this script."
    exit 1
fi

# --- Set permission and ownership ---
chmod +x "$AGENT_FILE"
chown root:root "$AGENT_FILE"
echo "Agent file downloaded and permissions set."

# --- Run installation (full scan mode) ---
echo "Running Device42 Agent installation (including virtual machines)..."
"$AGENT_PATH" | tee -a "$LOG_FILE"

# --- Ensure cron is installed and running ---
echo "Checking cron service..."
if ! rpm -q cronie >/dev/null 2>&1; then
    echo "Installing cronie..."
    if [ "$VERSION" -eq 7 ]; then
        yum install -y cronie
    else
        dnf install -y cronie
    fi
fi

systemctl enable crond
systemctl start crond
echo "Cron service verified."

# --- Setup cronjob ---
echo "Creating cron job for weekly run at 6:00 AM (Sunday)..."
cat > "$CRON_JOB" <<EOF
0 6 * * 0 root $INSTALL_DIR/$AGENT_FILE >> $LOG_FILE 2>&1
EOF

chmod 644 "$CRON_JOB"
chown root:root "$CRON_JOB"
echo "Cron job created: $CRON_JOB"

echo "Installation (full scan) completed successfully!"
