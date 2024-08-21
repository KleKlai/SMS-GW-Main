#!/bin/bash

# Create a network for the services
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