#!/bin/bash
#Loki + Node Exporter + Promtail
#Loki (3100), Node Exporter (9100), Promtail (9080)
set -e

LOKI_VERSION="3.5.7"
NODE_VERSION="1.8.2"
PROM_VERSION="3.0.0"
TMP_DIR="/tmp/loki_setup"
CONF_DIR="/etc/loki"
DATA_DIR="/var/lib/loki"
BIN_DIR="/usr/local/bin"

mkdir -p "${TMP_DIR}"
sudo apt update && sudo apt install -y wget unzip

#Loki
cd "${TMP_DIR}"
wget -q "https://github.com/grafana/loki/releases/download/v${LOKI_VERSION}/loki-linux-amd64.zip"
unzip -o loki-linux-amd64.zip
sudo mv loki-linux-amd64 "${BIN_DIR}/loki"
sudo chmod +x "${BIN_DIR}/loki"

getent group loki >/dev/null || groupadd --system loki
getent passwd loki >/dev/null || useradd --system --no-create-home --shell /sbin/nologin --gid loki loki

sudo mkdir -p "${DATA_DIR}/chunks" "${DATA_DIR}/rules" "${CONF_DIR}"
sudo cat <<EOF > "${CONF_DIR}/config.yml"
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: ${DATA_DIR}
  storage:
    filesystem:
      chunks_directory: ${DATA_DIR}/chunks
      rules_directory: ${DATA_DIR}/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2023-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  allow_structured_metadata: false
EOF

sudo cat <<EOF > /etc/systemd/system/loki.service
[Unit]
Description=Loki Log Aggregation
After=network.target

[Service]
User=loki
Group=loki
Type=simple
ExecStart=${BIN_DIR}/loki --config.file=${CONF_DIR}/config.yml
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

#Node Exporter
cd "${TMP_DIR}"
wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz"
tar xzvf "node_exporter-${NODE_VERSION}.linux-amd64.tar.gz"
sudo mv "node_exporter-${NODE_VERSION}.linux-amd64/node_exporter" "${BIN_DIR}/"

sudo cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=root
ExecStart=${BIN_DIR}/node_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

#Promtail
cd "${TMP_DIR}"
wget -q "https://github.com/grafana/loki/releases/download/v${PROM_VERSION}/promtail-linux-amd64.zip"
unzip -o promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 "${BIN_DIR}/promtail"
sudo chmod +x "${BIN_DIR}/promtail"
sudo mkdir -p /etc/promtail

sudo cat <<EOF > /etc/promtail/config.yml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://localhost:3100/loki/api/v1/push

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
ExecStart=${BIN_DIR}/promtail -config.file=/etc/promtail/config.yml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo chown -R loki:loki "${DATA_DIR}" "${CONF_DIR}"
sudo chmod -R 755 "${DATA_DIR}"

sudo systemctl daemon-reload
for srv in loki node_exporter promtail; do
    sudo systemctl enable --now $srv
done

sudo ufw allow 3100/tcp
sudo ufw allow 9100/tcp
sudo ufw allow 9080/tcp

rm -rf "${TMP_DIR}"
