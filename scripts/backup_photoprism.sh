#!/bin/bash
# Backup script for PhotoPrism MariaDB

BACKUP_DIR="./backups"
RETENTION_DAYS=7

docker exec photoprism-db /usr/bin/mysqldump -u root --password=RootSecurePassword123 photoprism > "$BACKUP_DIR/photoprism_db_$(date +%F).sql"

# Delete backups older than $RETENTION_DAYS
find "$BACKUP_DIR" -type f -mtime +$RETENTION_DAYS -exec rm -f {} \;

echo "Backup completed. Files older than $RETENTION_DAYS days were removed."