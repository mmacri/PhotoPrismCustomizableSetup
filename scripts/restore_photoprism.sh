#!/bin/bash
# Restore script for PhotoPrism MariaDB

if [ -z "$1" ]; then
  echo "Usage: $0 <backup-file.sql>"
  exit 1
fi

BACKUP_FILE="$1"
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file '$BACKUP_FILE' does not exist."
  exit 1
fi

read -p "This will overwrite the existing database. Are you sure? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Restore operation canceled."
  exit 0
fi

docker exec -i photoprism-db mysql -u root --password=RootSecurePassword123 photoprism < "$BACKUP_FILE"
echo "Restore complete."