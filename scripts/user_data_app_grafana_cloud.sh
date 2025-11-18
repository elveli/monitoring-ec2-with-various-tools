#!/bin/bash
set -euo pipefail
# ---------- CONFIG (replace) ----------
S3_APP_ZIP="s3://YOUR_BUCKET/nodejs_dynamic_ui.zip"
GRAFANA_CLOUD_METRICS_URL="https://prometheus-blocks-prod-us-central1.grafana.net/api/prom/push"
GRAFANA_CLOUD_LOGS_URL="https://logs-prod-us-central1.grafana.net/loki/api/v1/push"
GRAFANA_API_KEY="YOUR_GRAFANA_CLOUD_API_KEY"
# --------------------------------------
yum update -y
yum install -y unzip jq awscli
amazon-linux-extras enable nodejs18
yum install -y nodejs
mkdir -p /opt/nodeapp
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
AGENT_RPM="/tmp/grafana-agent.rpm"
curl -sSL -o "${AGENT_RPM}" "https://github.com/grafana/agent/releases/latest/download/grafana-agent-linux-amd64.rpm"
rpm -Uvh "${AGENT_RPM}"
mkdir -p /etc/grafana-agent
cat >/etc/grafana-agent/config.yaml <<GCFG
server:
  log_level: info
metrics:
  global:
    scrape_interval: 15s
  configs:
    - name: ec2
      scrape_configs:
        - job_name: nodeapp_metrics
          static_configs:
            - targets: ['localhost:3000']
      remote_write:
        - url: ${GRAFANA_CLOUD_METRICS_URL}
          basic_auth:
            username: "grafana"
            password: "${GRAFANA_API_KEY}"
logs:
  configs:
    - name: ec2-logs
      clients:
        - url: ${GRAFANA_CLOUD_LOGS_URL}
          basic_auth:
            username: "grafana"
            password: "${GRAFANA_API_KEY}"
      positions:
        filename: /tmp/positions.yaml
      scrape_configs:
        - job_name: nodeapp_logs
          static_configs:
            - targets: ['localhost']
              labels:
                __path__: /opt/nodeapp/*.log
        - job_name: system_logs
          static_configs:
            - targets: ['localhost']
              labels:
                __path__: /var/log/messages
GCFG
chown -R root:root /etc/grafana-agent
systemctl enable --now grafana-agent
