#!/bin/bash
# setup_photoprism_public.sh - Complete setup for PhotoPrism, MariaDB, Nginx, and optional Portainer.
# Author: Your Name
# Version: 1.0
# Description: This script sets up a full PhotoPrism stack with SSL, database backups, and optional Portainer.

set -e
LOG_FILE="./setup_photoprism.log"

# --- Utility Functions ---
check_prerequisites() {
  echo "Checking prerequisites..." | tee -a "$LOG_FILE"

  # Check Docker
  if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is not installed. Attempting to install..." | tee -a "$LOG_FILE"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      sudo apt-get update && sudo apt-get install -y docker.io
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      brew install --cask docker
    else
      echo "Unsupported OS. Please install Docker manually." | tee -a "$LOG_FILE"
      exit 1
    fi
  fi

  # Check Docker Compose
  if ! command -v docker-compose >/dev/null 2>&1; then
    echo "Docker Compose is not installed. Attempting to install..." | tee -a "$LOG_FILE"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      sudo apt-get install -y docker-compose
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      brew install docker-compose
    else
      echo "Unsupported OS. Please install Docker Compose manually." | tee -a "$LOG_FILE"
      exit 1
    fi
  fi

  # Check OpenSSL
  if ! command -v openssl >/dev/null 2>&1; then
    echo "OpenSSL is not installed. Attempting to install..." | tee -a "$LOG_FILE"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
      sudo apt-get install -y openssl
    elif [[ "$OSTYPE" == "darwin"* ]]; then
      brew install openssl
    else
      echo "Unsupported OS. Please install OpenSSL manually." | tee -a "$LOG_FILE"
      exit 1
    fi
  fi

  echo "All prerequisites are satisfied." | tee -a "$LOG_FILE"
}

get_user_inputs() {
  echo "Collecting user inputs..." | tee -a "$LOG_FILE"

  read -p "Enter Docker network name (default: photoprism_network): " DOCKER_NETWORK
  DOCKER_NETWORK=${DOCKER_NETWORK:-photoprism_network}

  read -p "Enter storage directory path (e.g., /path/to/storage): " STORAGE_DIR
  while [[ -z "$STORAGE_DIR" || ! -d "$STORAGE_DIR" ]]; do
    echo "Invalid path. Please provide an existing directory." | tee -a "$LOG_FILE"
    read -p "Enter storage directory path: " STORAGE_DIR
  done

  read -p "Enter originals directory path (e.g., /path/to/originals): " ORIGINALS_DIR
  while [[ -z "$ORIGINALS_DIR" || ! -d "$ORIGINALS_DIR" ]]; do
    echo "Invalid path. Please provide an existing directory." | tee -a "$LOG_FILE"
    read -p "Enter originals directory path: " ORIGINALS_DIR
  done

  read -p "Enter admin username for PhotoPrism: " PHOTOPRISM_ADMIN_USER
  read -s -p "Enter admin password for PhotoPrism: " PHOTOPRISM_ADMIN_PASSWORD
  echo

  read -p "Enter local IP address for Nginx (e.g., 192.168.1.100): " LOCAL_IP
  while [[ ! "$LOCAL_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; do
    echo "Invalid IP address. Please enter a valid IP." | tee -a "$LOG_FILE"
    read -p "Enter local IP address for Nginx: " LOCAL_IP
  done

  read -p "Enter domain for Nginx (or leave blank for local IP): " DOMAIN
  DOMAIN=${DOMAIN:-$LOCAL_IP}

  read -p "Include Portainer? (yes/no, default: yes): " INCLUDE_PORTAINER
  INCLUDE_PORTAINER=${INCLUDE_PORTAINER:-yes}
}

create_project_structure() {
  echo "Creating project structure..." | tee -a "$LOG_FILE"

  mkdir -p config/ssl backups scripts

  # Write environment variables
  cat > config/photoprism.env <<EOL
PHOTOPRISM_ADMIN_USER=$PHOTOPRISM_ADMIN_USER
PHOTOPRISM_ADMIN_PASSWORD=$PHOTOPRISM_ADMIN_PASSWORD
PHOTOPRISM_ORIGINALS=/photoprism/originals
PHOTOPRISM_STORAGE=/photoprism/storage
PHOTOPRISM_SITE_URL=https://$DOMAIN
PHOTOPRISM_DATABASE_DRIVER=mysql
PHOTOPRISM_DATABASE_SERVER=photoprism-db:3306
PHOTOPRISM_DATABASE_NAME=photoprism
PHOTOPRISM_DATABASE_USER=photoprism
PHOTOPRISM_DATABASE_PASSWORD=PhotoDBSecurePass123
PHOTOPRISM_DISABLE_TLS=false
PHOTOPRISM_WEB_DAV=true
EOL

  echo "Project structure created." | tee -a "$LOG_FILE"
}

generate_ssl_certificate() {
  echo "Generating SSL certificate for $DOMAIN..." | tee -a "$LOG_FILE"

  cat > config/ssl/openssl-san.cnf <<EOF
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
CN = $DOMAIN

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1  = $LOCAL_IP
EOF

  openssl req -new -newkey rsa:2048 -x509 -days 365 -nodes \
    -keyout config/ssl/photoprism.key -out config/ssl/photoprism.crt \
    -config config/ssl/openssl-san.cnf

  echo "SSL certificate generated." | tee -a "$LOG_FILE"
}

create_docker_compose() {
  echo "Creating Docker Compose configuration..." | tee -a "$LOG_FILE"

  cat > docker-compose.yml <<EOL
version: '3.8'

services:
  photoprism:
    image: photoprism/photoprism:latest
    container_name: photoprism
    restart: unless-stopped
    env_file: ./config/photoprism.env
    ports:
      - "2342:2342"
    volumes:
      - $ORIGINALS_DIR:/photoprism/originals
      - $STORAGE_DIR:/photoprism/storage
      - ./config/ssl:/certs
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
      - ./config/nginx.conf:/etc/nginx/conf.d/default.conf
      - ./config/ssl:/certs
    ports:
      - "443:443"
    networks:
      - $DOCKER_NETWORK

EOL

  if [[ "$INCLUDE_PORTAINER" == "yes" ]]; then
    cat >> docker-compose.yml <<EOL
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

  cat >> docker-compose.yml <<EOL
networks:
  $DOCKER_NETWORK:
    driver: bridge

volumes:
  photoprism_db_data:
EOL

  echo "Docker Compose configuration created." | tee -a "$LOG_FILE"
}

create_backup_script() {
  echo "Creating database backup script..." | tee -a "$LOG_FILE"

  cat > scripts/backup_photoprism.sh <<EOL
#!/bin/bash
# Backup script for PhotoPrism MariaDB

BACKUP_DIR="./backups"
RETENTION_DAYS=7

docker exec photoprism-db /usr/bin/mysqldump -u root --password=RootSecurePassword123 photoprism > "\$BACKUP_DIR/photoprism_db_\$(date +%F).sql"

# Delete backups older than \$RETENTION_DAYS
find "\$BACKUP_DIR" -type f -mtime +\$RETENTION_DAYS -exec rm -f {} \\;

echo "Backup completed. Files older than \$RETENTION_DAYS days were removed."
EOL

  chmod +x scripts/backup_photoprism.sh
  echo "Backup script created." | tee -a "$LOG_FILE"
}

# Main Script
check_prerequisites
get_user_inputs
create_project_structure
generate_ssl_certificate
create_docker_compose
create_backup_script

echo "Setup complete! Logs are saved in $LOG_FILE."
echo "Access PhotoPrism: https://$DOMAIN/"
if [[ "$INCLUDE_PORTAINER" == "yes" ]]; then
  echo "Access Portainer: http://$LOCAL_IP:9000"
fi
