#!/bin/bash
#Prometheus + Node Exporter + Promtail
#Prometheus (9090), Node Exporter (9100), Promtail (9080)
set -e

PROM_VERSION="3.5.1"
NODE_VERSION="1.8.2"
PTAIL_VERSION="3.0.0"
LOKI_URL="http://172.31.29.174:3100/loki/api/v1/push"
TMP_DIR="/tmp/monitoring_install"
CONF_DIR="/etc/prometheus"
DATA_DIR="/var/lib/prometheus"

mkdir -p "${TMP_DIR}"
sudo apt update && sudo apt install -y wget unzip

#Prometheus
cd "${TMP_DIR}"
wget -q "https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz"
tar xzvf "prometheus-${PROM_VERSION}.linux-amd64.tar.gz"

getent group prometheus >/dev/null || groupadd --system prometheus
getent passwd prometheus >/dev/null || useradd -s /sbin/nologin --system -g prometheus prometheus
mkdir -p "${DATA_DIR}" "${CONF_DIR}/rules" "${CONF_DIR}/files_sd"
cd "prometheus-${PROM_VERSION}.linux-amd64"
sudo mv prometheus promtool /usr/local/bin/
sudo mv prometheus.yml "${CONF_DIR}/"
[ -d "consoles" ] && sudo mv consoles "${CONF_DIR}/"
[ -d "console_libraries" ] && sudo mv console_libraries "${CONF_DIR}/"

sudo cat > /etc/systemd/system/prometheus.service << EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=prometheus
Group=prometheus
ExecStart=/usr/local/bin/prometheus \\
  --config.file=${CONF_DIR}/prometheus.yml \\
  --storage.tsdb.path=${DATA_DIR} \\
  --web.listen-address=0.0.0.0:9090

Restart=always
EOF

#Node exporter
cd "${TMP_DIR}"
wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz"
tar xzvf "node_exporter-${NODE_VERSION}.linux-amd64.tar.gz"
sudo mv "node_exporter-${NODE_VERSION}.linux-amd64/node_exporter" /usr/local/bin/

sudo cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

#Promtail
cd "${TMP_DIR}"
wget -q "https://github.com/grafana/loki/releases/download/v${PTAIL_VERSION}/promtail-linux-amd64.zip"
unzip -o promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
sudo chmod +x /usr/local/bin/promtail
sudo mkdir -p /etc/promtail

sudo cat <<EOF > /etc/promtail/config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: ${LOKI_URL}

scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      job: varlogs
      host: $(hostname)
      __path__: /var/log/*.log
EOF

sudo cat <<EOF > /etc/systemd/system/promtail.service
[Unit]
Description=Promtail service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo chown -R prometheus:prometheus "${CONF_DIR}" "${DATA_DIR}"
sudo chmod -R 775 "${CONF_DIR}" "${DATA_DIR}"

sudo systemctl daemon-reload
for srv in prometheus node_exporter promtail; do
    sudo systemctl enable --now $srv
done

rm -rf "${TMP_DIR}"
