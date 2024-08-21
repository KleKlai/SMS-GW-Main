#!/bin/bash

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Set up the Docker stable repository without requiring user interaction
sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update the apt package index
sudo apt-get update -y

# Install the latest version of Docker CE without requiring user interaction
sudo apt-get install -y docker-ce

# Start Docker
sudo systemctl start docker

# Enable Docker to start on boot
sudo systemctl enable docker

# Create Docker network named sms_gateway_network
docker network create sms_gateway_network

# Run Caddy container and connect to the bridge network
docker run -d \
  --name caddy \
  --restart unless-stopped \
  --network bridge \
  -p 80:80 \
  -p 443:443 \
  -v ./Caddyfile:/etc/caddy/Caddyfile \
  -v caddy_data:/data \
  -v caddy_config:/config \
  caddy:latest

# Connect the Caddy container to the sms_gateway_network
docker network connect sms_gateway_network caddy

# Run Portainer container on the bridge network
docker run -d \
  -p 9000:9000 \
  --name=portainer \
  --restart=always \
  --network bridge \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce

# Run MariaDB container on the sms_gateway_network with remote access enabled
docker run -d \
  --name mariadb \
  --restart always \
  --network sms_gateway_network \
  -e MYSQL_ROOT_PASSWORD=bxtr1605 \
  -e MYSQL_DATABASE=sms \
  -e MYSQL_USER=root \
  -e MYSQL_PASSWORD=bxtr1605 \
  -v mariadb_data:/var/lib/mysql \
  -p 3306:3306 \
  mariadb:10.11 \
  --bind-address=0.0.0.0 # remove bind-address if used in production

# Create a network for the monitoring services
docker network create monitoring-network

# Run Prometheus container
docker run -d \
  --name=prometheus \
  --network=monitoring-network \
  -v $(pwd)/prometheus.yml:/etc/prometheus/prometheus.yml \
  -p 9090:9090 \
  prom/prometheus:latest \
  --config.file=/etc/prometheus/prometheus.yml

# Run Node Exporter container
docker run -d \
  --name=node-exporter \
  --network=monitoring-network \
  -p 9100:9100 \
  prom/node-exporter:latest

# Run Grafana container
docker run -d \
  --name=grafana \
  --network=monitoring-network \
  -p 3000:3000 \
  grafana/grafana:latest

# Output the status of all services
echo "Services are up and running:"
docker ps

# Instructions for Grafana setup
echo "Grafana is accessible at http://localhost:3000"
echo "Prometheus is accessible at http://localhost:9090"
echo "Node Exporter is accessible at http://localhost:9100"