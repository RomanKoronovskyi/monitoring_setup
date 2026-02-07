#!/bin/bash
#documentation: https://grafana.com/grafana/download
#access: http://ip:3000
set -e

VERSION="12.3.2"
SERVICE="grafana-server"
URL="https://dl.grafana.com/grafana-enterprise/release/${VERSION}/grafana-enterprise_${VERSION}_21390657659_linux_amd64.deb"
DEB="grafana-enterprise_${VERSION}_21390657659_linux_amd64.deb"

sudo apt update && sudo apt upgrade -y
sudo apt-get install -y adduser libfontconfig1 musl
wget "${URL}"
sudo dpkg -i "${DEB}"

sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE}"
sudo systemctl start "${SERVICE}"

echo "Config: /etc/grafana/grafana.ini"
echo "Data: /var/lib/grafana/"
