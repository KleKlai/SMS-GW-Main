#!/bin/bash

# This script is for installing the node exporter and prometheus to host machine

# Download and extract Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar xvfz prometheus-2.45.0.linux-amd64.tar.gz
cd prometheus-2.45.0.linux-amd64

# Get the current directory
PROMETHEUS_PATH=$(pwd)

# Create Prometheus configuration file
cat <<EOT > $PROMETHEUS_PATH/prometheus.yml
global:
  scrape_interval: 3s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOT

# Create systemd service file for Prometheus
sudo bash -c "cat <<EOT > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=root
ExecStart=$PROMETHEUS_PATH/prometheus --config.file=$PROMETHEUS_PATH/prometheus.yml
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOT"

# Reload the systemd daemon
sudo systemctl daemon-reload

# Start and enable Prometheus service
sudo systemctl start prometheus
sudo systemctl enable prometheus

# Download and extract Node Exporter
cd ~
wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.5.0.linux-amd64.tar.gz
cd node_exporter-1.5.0.linux-amd64

# Start Node Exporter
./node_exporter &

# Install Grafana
# sudo apt-get install -y gnupg
# sudo mkdir -p /etc/apt/keyrings
# curl -fsSL https://packages.grafana.com/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/grafana-archive-keyring.gpg
# echo "deb [signed-by=/etc/apt/keyrings/grafana-archive-keyring.gpg] https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# sudo apt-get update
# sudo apt-get install grafana -y

# # Start and enable Grafana service
# sudo systemctl start grafana-server
# sudo systemctl enable grafana-server

# Pull the Grafana Docker image
docker pull grafana/grafana:latest

# Run Grafana container
docker run -d \
  -p 3000:3000 \
  --name=grafana \
  --restart unless-stopped \
  grafana/grafana:latest

echo "Prometheus, Node Exporter, and Grafana have been installed and configured."

# Guide for Grafana Setup:
# After running the script, follow these steps to configure Grafana:

# 4. Configure Grafana:
# Add Prometheus as a Data Source:

# Go to Configuration > Data Sources > Add Data Source in Grafana.
# Choose Prometheus.
# Set the URL to http://localhost:9090 and save.
# Import or Create Dashboards:

# Grafana has pre-built dashboards for Node Exporter.
# Go to Dashboards > Import, then use the dashboard ID 1860 (Node Exporter Full) to import a comprehensive dashboard for monitoring system metrics.
# 5. Set Up Alerts (Optional):
# You can configure alerts in Prometheus or Grafana to notify you if certain thresholds (e.g., high CPU usage) are crossed.