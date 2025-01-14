#!/bin/bash
# setup_photoprism_public.sh - Comprehensive setup for PhotoPrism, MariaDB, Nginx, and optional Portainer.

set -e  # Exit on error
LOG_FILE="./setup_photoprism.log"
trap 'echo "Error occurred. Check $LOG_FILE for details."; exit 1' ERR

# --- Utility Functions ---
log_message() {
  echo "$1" | tee -a "$LOG_FILE"
}

check_prerequisites() {
  log_message "Checking prerequisites..."

  for cmd in docker docker-compose openssl; do
    if ! command -v $cmd >/dev/null 2>&1; then
      log_message "Error: $cmd is not installed. Please install it before running this script."
      exit 1
    fi
  done

  log_message "All prerequisites are satisfied."
}

get_user_inputs() {
  log_message "Collecting user inputs..."

  read -p "Enter Docker network name (default: photoprism_network): " DOCKER_NETWORK
  DOCKER_NETWORK=${DOCKER_NETWORK:-photoprism_network}

  read -p "Enter storage directory path (e.g., /path/to/storage): " STORAGE_DIR
  if [[ ! -d $STORAGE_DIR ]]; then
    log_message "Error: Storage directory does not exist."
    exit 1
  fi

  read -p "Enter originals directory path (e.g., /path/to/originals): " ORIGINALS_DIR
  if [[ ! -d $ORIGINALS_DIR ]]; then
    log_message "Error: Originals directory does not exist."
    exit 1
  fi

  read -p "Enter admin username for PhotoPrism: " PHOTOPRISM_ADMIN_USER
  read -s -p "Enter admin password for PhotoPrism: " PHOTOPRISM_ADMIN_PASSWORD
  echo

  read -p "Enter local IP address for Nginx (e.g., 192.168.1.100): " LOCAL_IP
  if [[ ! $LOCAL_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_message "Error: Invalid IP address format."
    exit 1
  fi

  read -p "Enter domain for Nginx (or leave blank for local IP): " DOMAIN
  DOMAIN=${DOMAIN:-$LOCAL_IP}

  read -p "Include Portainer? (yes/no, default: yes): " INCLUDE_PORTAINER
  INCLUDE_PORTAINER=${INCLUDE_PORTAINER:-yes}
}

create_project_structure() {
  log_message "Creating project structure..."
  mkdir -p config/ssl backups scripts
}

generate_ssl_certificate() {
  log_message "Generating SSL certificate for $DOMAIN..."

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
    -config config/ssl/openssl-san.cnf || {
    log_message "Error: SSL certificate generation failed."
    exit 1
  }

  log_message "SSL certificate generated successfully."
}

create_docker_compose() {
  log_message "Creating Docker Compose configuration..."

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

  log_message "Docker Compose configuration created."
}

create_backup_and_restore_scripts() {
  log_message "Creating backup and restore scripts..."

  cat > scripts/backup_photoprism.sh <<EOL
#!/bin/bash
BACKUP_DIR="./backups"
RETENTION_DAYS=7
mkdir -p "\$BACKUP_DIR"
docker exec photoprism-db /usr/bin/mysqldump -u root --password=RootSecurePassword123 photoprism > "\$BACKUP_DIR/photoprism_db_\$(date +%F).sql"
find "\$BACKUP_DIR" -type f -mtime +\$RETENTION_DAYS -exec rm -f {} \;
EOL
  chmod +x scripts/backup_photoprism.sh

  cat > scripts/restore_photoprism.sh <<EOL
#!/bin/bash
if [ -z "\$1" ]; then
  echo "Usage: \$0 <backup-file.sql>"
  exit 1
fi
docker exec -i photoprism-db mysql -u root --password=RootSecurePassword123 photoprism < "\$1"
EOL
  chmod +x scripts/restore_photoprism.sh

  log_message "Backup and restore scripts created."
}

# --- Main Execution ---
check_prerequisites
get_user_inputs
create_project_structure
generate_ssl_certificate
create_docker_compose
create_backup_and_restore_scripts

log_message "Setup complete! Access PhotoPrism: https://$DOMAIN/"
[[ "$INCLUDE_PORTAINER" == "yes" ]] && log_message "Access Portainer: http://$LOCAL_IP:9000"
