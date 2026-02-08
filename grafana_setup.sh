#!/bin/bash
# Node Exporter + Promtail + Grafana
# Grafana (3000), Node Exporter (9100), Promtail (9080)
set -e

NODE_VERSION="1.8.2"
PROM_VERSION="3.0.0"
GRAFANA_VERSION="12.3.2"
LOKI_URL="http://172.31.29.174:3100/loki/api/v1/push"
DEB_NAME="grafana-enterprise_${GRAFANA_VERSION}_21390657659_linux_amd64.deb"
URL="https://dl.grafana.com/grafana-enterprise/release/${GRAFANA_VERSION}/${DEB_NAME}"

sudo apt update && sudo apt upgrade -y
sudo apt install -y wget unzip adduser libfontconfig1 musl

#Node Exporter
cd /tmp
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
wget -q "https://github.com/grafana/loki/releases/download/v${PROM_VERSION}/promtail-linux-amd64.zip"
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

#Grafana
wget -q "${URL}"
sudo dpkg -i "${DEB_NAME}"

#start services
sudo systemctl daemon-reload

for service in node_exporter promtail grafana-server; do
    sudo systemctl enable --now $service
done

rm -rf /tmp/node_exporter* /tmp/promtail* /tmp/*.deb /tmp/*.gz
