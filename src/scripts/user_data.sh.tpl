#!/bin/bash
set -e

# Log user-data output to file and console
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/null) 2>&1
echo "Starting bootstrap script..."

# Update packages and install dependencies
dnf update -y
dnf install -y amazon-cloudwatch-agent jq nodejs npm

# Create application directory and user
mkdir -p /opt/three-tier-app
useradd -r -s /bin/false appuser || true

# Fetch Database Credentials from Secrets Manager if secret ARN provided
if [ -n "${db_secret_arn}" ]; then
  echo "Fetching DB secrets from AWS Secrets Manager..."
  SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "${db_secret_arn}" --region "${aws_region}" --query SecretString --output text)
  export DB_HOST=$(echo $SECRET_JSON | jq -r .host)
  export DB_USER=$(echo $SECRET_JSON | jq -r .username)
  export DB_PASSWORD=$(echo $SECRET_JSON | jq -r .password)
  export DB_NAME=$(echo $SECRET_JSON | jq -r .dbname)
  export DB_PORT=$(echo $SECRET_JSON | jq -r .port)
else
  export DB_HOST="${db_host}"
  export DB_USER="${db_user}"
  export DB_PASSWORD="${db_password}"
  export DB_NAME="${db_name}"
  export DB_PORT="${db_port}"
fi

# Write application files
cat <<'EOF' > /opt/three-tier-app/package.json
${package_json}
EOF

cat <<'EOF' > /opt/three-tier-app/index.js
${app_index_js}
EOF

mkdir -p /opt/three-tier-app/public
cat <<'EOF' > /opt/three-tier-app/public/index.html
${app_index_html}
EOF

cd /opt/three-tier-app
npm install --production
chown -R appuser:appuser /opt/three-tier-app

# Create environment variable file for Systemd
cat <<EOF > /opt/three-tier-app/.env
PORT=${app_port}
NODE_ENV=production
DB_HOST=$DB_HOST
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_NAME=$DB_NAME
DB_PORT=$DB_PORT
EOF

chmod 600 /opt/three-tier-app/.env
chown appuser:appuser /opt/three-tier-app/.env

# Create Systemd Service for App
cat <<EOF > /etc/systemd/system/three-tier-app.service
[Unit]
Description=AWS Three-Tier Sample Application Server
After=network.target

[Service]
Type=simple
User=appuser
WorkingDirectory=/opt/three-tier-app
EnvironmentFile=/opt/three-tier-app/.env
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable three-tier-app
systemctl start three-tier-app

# Configure CloudWatch Agent
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/system-messages"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "${log_group_name}",
            "log_stream_name": "{instance_id}/user-data"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "measurement": ["used_percent"],
        "resources": ["/"]
      }
    }
  }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

echo "Bootstrap completed successfully."
