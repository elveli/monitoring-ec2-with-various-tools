#!/bin/bash
set -euo pipefail
S3_APP_ZIP="s3://YOUR_BUCKET/nodejs_dynamic_ui.zip"
PROMETHEUS_VOLUME="/mnt/prometheus"
LOKI_VOLUME="/mnt/loki"
GRAFANA_ADMIN_PASSWORD="admin"
yum update -y
yum install -y unzip jq awscli git
amazon-linux-extras install docker -y
systemctl enable --now docker
usermod -a -G docker ec2-user
DOCKER_COMPOSE_BIN="/usr/local/bin/docker-compose"
if [ ! -f "${DOCKER_COMPOSE_BIN}" ]; then
  curl -sSL -o "${DOCKER_COMPOSE_BIN}" "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64"
  chmod +x "${DOCKER_COMPOSE_BIN}"
fi
mkdir -p /opt/nodeapp /opt/monitoring ${PROMETHEUS_VOLUME} ${LOKI_VOLUME}
chown -R ec2-user:ec2-user /opt/nodeapp /opt/monitoring ${PROMETHEUS_VOLUME} ${LOKI_VOLUME}
cd /opt/nodeapp
if aws s3 ls "${S3_APP_ZIP}" >/dev/null 2>&1; then aws s3 cp "${S3_APP_ZIP}" app.zip; else echo "ERROR: app zip not found in S3: ${S3_APP_ZIP}" >&2; exit 1; fi
unzip -o app.zip
npm install --production || true
cat >/etc/systemd/system/nodeapp.service <<'EOF'
[Unit]
Description=Node.js Dynamic UI
After=network.target
[Service]
ExecStart=/usr/bin/node /opt/nodeapp/server.js
Restart=always
User=ec2-user
WorkingDirectory=/opt/nodeapp
Environment=PORT=3000
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now nodeapp.service
cat >/opt/monitoring/prometheus.yml <<PROM
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ['localhost:9090']
  - job_name: node_exporter
    static_configs:
      - targets: ['localhost:9100']
  - job_name: nodeapp
    static_configs:
      - targets: ['localhost:3000']
PROM
cat >/opt/monitoring/loki-config.yaml <<LOKI
auth_enabled: false
server:
  http_listen_port: 3100
common:
  path_prefix: /loki
schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h
storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks
limits_config:
  enforce_metric_name: false
LOKI
cat >/opt/monitoring/promtail-config.yaml <<PROMT
server:
  http_listen_port: 9080
positions:
  filename: /tmp/positions.yaml
clients:
  - url: http://loki:3100/loki/api/v1/push
scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/messages
  - job_name: nodeapp
    static_configs:
      - targets: [localhost]
        labels:
          job: nodeapp
          __path__: /opt/nodeapp/*.log
PROMT
cat >/opt/monitoring/docker-compose.yml <<DC
version: "3.7"
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ${PROMETHEUS_VOLUME}:/prometheus
    ports:
      - "9090:9090"
  grafana:
    image: grafana/grafana:latest
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
      - loki
    volumes:
      - grafana-storage:/var/lib/grafana
  loki:
    image: grafana/loki:2.9.1
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - ./loki-config.yaml:/etc/loki/local-config.yaml:ro
      - ${LOKI_VOLUME}:/loki
    ports:
      - "3100:3100"
  promtail:
    image: grafana/promtail:2.9.1
    volumes:
      - ./promtail-config.yaml:/etc/promtail/promtail.yaml:ro
      - /var/log:/var/log:ro
      - /opt/nodeapp:/opt/nodeapp:ro
    command: -config.file=/etc/promtail/promtail.yaml
volumes:
  grafana-storage:
DC
chown -R ec2-user:ec2-user /opt/monitoring
cd /opt/monitoring
sudo -u ec2-user "${DOCKER_COMPOSE_BIN}" up -d
cd /tmp
NODE_EXPORTER_VERSION="1.6.1"
curl -sL "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" -o node_exporter.tar.gz
tar xzf node_exporter.tar.gz
cp node_exporter-*/node_exporter /usr/local/bin/
useradd -r -M -s /sbin/nologin nodeusr || true
cat >/etc/systemd/system/node_exporter.service <<NE
[Unit]
Description=Prometheus Node Exporter
After=network.target
[Service]
User=nodeusr
ExecStart=/usr/local/bin/node_exporter
Restart=always
[Install]
WantedBy=multi-user.target
NE
systemctl daemon-reload
systemctl enable --now node_exporter.service
echo "Monitoring stack started."
