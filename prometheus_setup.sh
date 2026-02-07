#!/bin/bash
#documentation: https://prometheus.io/download/
#documentation: https://github.com/prometheus/prometheus/releases
#access: http://ip:9090
set -e

echo "prometheus" > /etc/hostname
hostname prometheus

PROM_VERSION="3.5.1"
DOWNLOAD_URL="https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
TAR_FILE="prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
TMP_DIR="/tmp/prometheus"
DATA_DIR="/var/lib/prometheus"
CONF_DIR="/etc/prometheus"
EXTRACT_DIR="prometheus-${PROM_VERSION}.linux-amd64"
BIN_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/prometheus.service"

mkdir -p "${TMP_DIR}"
cd "${TMP_DIR}"
wget "${DOWNLOAD_URL}"
tar xzvf "${TAR_FILE}"

#group + user
groupadd --system prometheus
useradd -s /sbin/nologin --system -g prometheus prometheus

mkdir -p "${DATA_DIR}"
chown -R prometheus:prometheus "${DATA_DIR}"
chmod -R 775 "${DATA_DIR}"

mkdir -p "${CONFIG_DIR}/rules"
mkdir -p "${CONFIG_DIR}/rules.s"
mkdir -p "${CONFIG_DIR}/files_sd"

cd "${EXTRACT_DIR}"
mv prometheus promtool "${BIN_DIR}"
mv prometheus.yml "${CONFIG_DIR}"

# Create systemd service file
cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries \\
  --web.listen-address=0.0.0.0:9090 \\
  --web.enable-remote-write-receiver

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target
EOF

chown -R prometheus:prometheus "${CONFIG_DIR}"
chmod -R 775 "${CONFIG_DIR}"
chown -R prometheus:prometheus "${DATA_DIR}"

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus













