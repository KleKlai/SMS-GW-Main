#!/bin/bash

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Installing jq..."
    
    # Install jq on Ubuntu
    sudo apt-get update
    sudo apt-get install -y jq
fi

echo "jq is installed."

# Check if the correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <container_name> <port> <subdomain>"
    echo "Example: $0 davao 3001 davao"
    exit 1
fi

# Assign arguments to variables
CONTAINER_NAME=$1
PORT=$2
SUBDOMAIN=$3

# Prepend "0.0.0.0:" to the provided port
HTTP_LISTEN="0.0.0.0:${PORT}"

# Generate a unique 4-character string
UNIQUE_SUFFIX=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 4)

# Append the unique suffix to the container name
CONTAINER_NAME="${CONTAINER_NAME}_${UNIQUE_SUFFIX}"

# Set static database host
DATABASE_HOST="mariadb"

# Run the Docker container with dynamic values
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  --network sms_gateway_network \
  -p ${PORT}:${PORT} \
  -e CONFIG_PATH=config.yml \
  -e HTTP__LISTEN=$HTTP_LISTEN \
  -e DATABASE__HOST=$DATABASE_HOST \
  -e DATABASE__PORT=3306 \
  -e DATABASE__USER=root \
  -e DATABASE__PASSWORD=bxtr1605 \
  -e DATABASE__DATABASE=$CONTAINER_NAME \
  -v $(pwd)/config.yml:/app/config.yml:ro \
  capcom6/sms-gateway

# Check if the docker run command was successful
if [ $? -ne 0 ]; then
    echo "Error: Docker container failed to start, possibly due to a port conflict."
    
    # Stop and remove the newly created container
    docker stop $CONTAINER_NAME >/dev/null 2>&1
    docker rm $CONTAINER_NAME >/dev/null 2>&1

    echo "Stopped and removed the container $CONTAINER_NAME due to port conflict."
    exit 1
fi

# Access the MariaDB container and create the new database
docker exec -i mariadb mysql -uroot -p"bxtr1605" -e "CREATE DATABASE IF NOT EXISTS $CONTAINER_NAME;" 2>&1 | tee /tmp/mysql_output.log

# Check if there was an SQL error
if grep -q "ERROR" /tmp/mysql_output.log; then
    echo "Error: SQL error occurred during database creation."
    exit 1
fi

# Get the public IPv4 address of the current server
PUBLIC_IP=$(curl -s -4 ifconfig.me)

# Make an API call to Cloudflare to create a new DNS record and capture the response
CLOUDFLARE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/3867a8be8d5db2b4d29604d3c1c00944/dns_records" \
    -H "Authorization: Bearer HJBZhQtdMoYOC7OTFFNiTfmS9mXR6BDiVZ_Diuf8" \
    -H "Content-Type: application/json" \
    --data '{
        "type": "A",
        "name": "'"${SUBDOMAIN}"'",
        "content": "'"${PUBLIC_IP}"'",
        "ttl": 120,
        "proxied": false,
        "comment": "Created by Zenglobal"
    }')

# Extract the zone_name from the Cloudflare API response
ZONE_NAME=$(echo $CLOUDFLARE_RESPONSE | jq -r '.result.zone_name')

# Edit the Caddyfile to include the reverse proxy configuration using the extracted zone_name
NEW_CADDY_ENTRY="${SUBDOMAIN}.${ZONE_NAME} {
    reverse_proxy ${CONTAINER_NAME}:${PORT}
}"
echo "${NEW_CADDY_ENTRY}" >> ./Caddyfile

# Reload the Caddy server to apply the new configuration
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# Validate if the new configuration is reflected in the Caddyfile inside the container
VALIDATION=$(docker exec caddy cat /etc/caddy/Caddyfile | grep -F "${NEW_CADDY_ENTRY}")

if [ -n "$VALIDATION" ]; then
    echo "New Caddyfile entry is successfully reflected."
else
    echo "Error: New Caddyfile entry is not reflected in the Caddy container."
    exit 1
fi
