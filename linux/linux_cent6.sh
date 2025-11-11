#!/bin/bash
# Device42 Agent Installer Script (CentOS 6, Skip Virtual Machines, Timestamped Logs)
# Must be run as root
# Tested for CentOS 6.x

set -e

DOWNLOAD_URL="https://github.com/mohdyazidms/d42/releases/download/v1.4/d42_linuxagent_x64"
INSTALL_DIR="/opt/device42"
AGENT_FILE="d42_linuxagent_x64"
AGENT_PATH="$INSTALL_DIR/$AGENT_FILE"
CRON_JOB="/etc/cron.d/device42_agent"
LOG_FILE="/var/log/device42_install.log"

# --- Ensure script runs as root ---
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root."
    exit 1
fi

# --- Ensure required tools ---
echo "Checking for required tools: curl/wget and gawk..."
if ! command -v gawk >/dev/null 2>&1; then
    echo "gawk is required. Installing..."
    yum install -y gawk
fi

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "Installing curl..."
    yum install -y curl
fi

# --- Prepare installation directory ---
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# --- Download agent binary ---
echo "Downloading Device42 Agent..."
if command -v curl >/dev/null 2>&1; then
    curl -L -o "$AGENT_FILE" "$DOWNLOAD_URL"
elif command -v wget >/dev/null 2>&1; then
    wget -O "$AGENT_FILE" "$DOWNLOAD_URL"
fi

# --- Set permissions and ownership ---
chmod +x "$AGENT_FILE"
chown root:root "$AGENT_FILE"
echo "Agent downloaded and permissions set."

# --- Run installation (skip virtual machines) with timestamped logs ---
echo "Running Device42 Agent installation (skipping virtual machines)..."
"$AGENT_PATH" -skip-virtual-machines 2>&1 | gawk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush(); }' | tee -a "$LOG_FILE"

# --- Ensure cron service is installed and running ---
echo "Checking cron service..."
if ! rpm -q cronie >/dev/null 2>&1; then
    echo "Installing cronie..."
    yum install -y cronie
fi

service crond start
chkconfig crond on
echo "Cron service started and enabled."

# --- Setup weekly cronjob (Sunday 6:00 AM) with timestamped logs ---
echo "Creating cron job for weekly run..."
cat > "$CRON_JOB" <<EOF
0 6 * * 0 root $INSTALL_DIR/$AGENT_FILE -skip-virtual-machines 2>&1 | gawk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), \$0; fflush(); }' >> $LOG_FILE
EOF

chmod 644 "$CRON_JOB"
chown root:root "$CRON_JOB"
echo "Cron job created at $CRON_JOB"

echo "Installation (skip virtual machines) completed successfully!"
echo "Logs can be found at $LOG_FILE"
