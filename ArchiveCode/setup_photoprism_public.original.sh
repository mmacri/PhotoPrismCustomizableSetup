#!/bin/bash
# setup_photoprism_public.sh - Full setup for PhotoPrism, MariaDB, Nginx, backups, and optional Portainer.
# Prompts for user-specific configuration to ensure flexibility for diverse environments.

set -e
LOG_FILE="./setup_photoprism_public.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting setup..." | tee "$LOG_FILE"

# --- 1. Prompts for User Input ---
read -p "Enter Docker network name (default: photoprism_network): " DOCKER_NETWORK
DOCKER_NETWORK=${DOCKER_NETWORK:-photoprism_network}

read -p "Enter storage directory path (e.g., /path/to/storage): " STORAGE_DIR
read -p "Enter originals directory path (e.g., /path/to/originals): " ORIGINALS_DIR

read -p "Enter admin username for PhotoPrism: " PHOTOPRISM_ADMIN_USER
read -s -p "Enter admin password for PhotoPrism: " PHOTOPRISM_ADMIN_PASSWORD
printf "\n"

read -p "Enter local IP address for Nginx (e.g., 192.168.1.100): " LOCAL_IP
read -p "Enter domain for Nginx (or leave blank for local IP): " DUCKDNS_DOMAIN
DUCKDNS_DOMAIN=${DUCKDNS_DOMAIN:-$LOCAL_IP}

read -p "Enable Portainer? (yes/no, default: yes): " ENABLE_PORTAINER
ENABLE_PORTAINER=${ENABLE_PORTAINER:-yes}

# --- 2. Dependency Check ---
if ! command -v docker >/dev/null; then
  echo "Docker not installed. Install Docker Desktop." | tee -a "$LOG_FILE"
  exit 1
fi
if ! command -v openssl >/dev/null; then
  echo "OpenSSL not found. Install it (e.g., choco install openssl)." | tee -a "$LOG_FILE"
  exit 1
fi

# --- 3. Create Directories ---
SSL_DIR="./ssl"
BACKUP_DIR="./backups"
mkdir -p "$SSL_DIR" "$BACKUP_DIR" "$STORAGE_DIR"

# --- 4. Create .env File ---
ENV_FILE="./photoprism.env"
cat > "$ENV_FILE" <<EOL
PHOTOPRISM_ADMIN_USER=${PHOTOPRISM_ADMIN_USER}
PHOTOPRISM_ADMIN_PASSWORD=${PHOTOPRISM_ADMIN_PASSWORD}
PHOTOPRISM_SITE_URL=https://${DUCKDNS_DOMAIN}:443
PHOTOPRISM_ORIGINALS=/photoprism/originals
PHOTOPRISM_STORAGE=/photoprism/storage
PHOTOPRISM_DATABASE_DRIVER=mysql
PHOTOPRISM_DATABASE_SERVER=photoprism-db:3306
PHOTOPRISM_DATABASE_NAME=photoprism
PHOTOPRISM_DATABASE_USER=photoprism
PHOTOPRISM_DATABASE_PASSWORD=PhotoDBSecurePass123
PHOTOPRISM_DISABLE_TLS=false
PHOTOPRISM_WEB_DAV=true
EOL

# --- 5. Generate SSL Certificate ---
CERT_FILE="$SSL_DIR/photoprism.crt"
KEY_FILE="$SSL_DIR/photoprism.key"
OPENSSL_CNF="./openssl-san.cnf"
cat > "$OPENSSL_CNF" <<EOF
[ req ]
distinguished_name = dn
default_bits       = 2048
prompt             = no
default_md         = sha256
x509_extensions    = req_ext

[ dn ]
C = US
ST = State
L = City
O = Company
OU = IT
CN = ${DUCKDNS_DOMAIN}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = ${DUCKDNS_DOMAIN}
DNS.2 = localhost
IP.1  = ${LOCAL_IP}
EOF
openssl req -new -newkey rsa:2048 -x509 -days 365 -nodes -keyout "$KEY_FILE" -out "$CERT_FILE" -config "$OPENSSL_CNF" -extensions req_ext

# --- 6. Nginx Configuration ---
NGINX_CONFIG="./nginx.conf"
cat > "$NGINX_CONFIG" <<EOL
server {
  listen 443 ssl;
  server_name ${DUCKDNS_DOMAIN} ${LOCAL_IP} localhost;
  ssl_certificate /certs/photoprism.crt;
  ssl_certificate_key /certs/photoprism.key;
  location / { proxy_pass http://photoprism:2342; }
}
EOL

# --- 7. Docker Compose ---
DOCKER_COMPOSE_FILE="./docker-compose.yml"
cat > "$DOCKER_COMPOSE_FILE" <<EOL
version: '3.8'
services:
  photoprism:
    image: photoprism/photoprism:latest
    container_name: photoprism
    restart: unless-stopped
    env_file: $ENV_FILE
    ports:
      - "2342:2342"
    volumes:
      - "$ORIGINALS_DIR:/photoprism/originals"
      - "$STORAGE_DIR:/photoprism/storage"
      - "$SSL_DIR:/certs"
    networks:
      - $DOCKER_NETWORK

  photoprism-db:
    image: mariadb:latest
    container_name: photoprism-db
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: RootSecurePassword123
      MYSQL_DATABASE: photoprism
      MYSQL_USER: photoprism
      MYSQL_PASSWORD: PhotoDBSecurePass123
    volumes:
      - photoprism_db_data:/var/lib/mysql
    networks:
      - $DOCKER_NETWORK

  nginx:
    image: nginx:latest
    container_name: nginx
    restart: unless-stopped
    volumes:
      - "$NGINX_CONFIG:/etc/nginx/conf.d/default.conf"
      - "$SSL_DIR:/certs"
    ports:
      - "443:443"
    networks:
      - $DOCKER_NETWORK

EOL

if [ "$ENABLE_PORTAINER" == "yes" ]; then
  cat >> "$DOCKER_COMPOSE_FILE" <<EOL
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - $DOCKER_NETWORK
EOL
fi

cat >> "$DOCKER_COMPOSE_FILE" <<EOL
networks:
  $DOCKER_NETWORK:
    driver: bridge
volumes:
  photoprism_db_data:
EOL

# --- 8. Start Docker Compose ---
echo "Starting Docker Compose stack..." | tee -a "$LOG_FILE"
docker-compose -f "$DOCKER_COMPOSE_FILE" down || true
docker-compose -f "$DOCKER_COMPOSE_FILE" up -d

# --- 9. Completion ---
echo "Setup complete! Access PhotoPrism at https://${DUCKDNS_DOMAIN}/ or https://${LOCAL_IP}/" | tee -a "$LOG_FILE"
if [ "$ENABLE_PORTAINER" == "yes" ]; then
  echo "Access Portainer at http://${LOCAL_IP}:9000" | tee -a "$LOG_FILE"
fi
