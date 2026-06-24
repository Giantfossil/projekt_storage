#!/usr/bin/env bash

# ==============================================================================
# Skript: backup_ssd.sh
# Beschreibung: Führt ein Backup der VM-Images (/var/lib/libvirt) von der SSD
#               auf das externe Backup-Laufwerk (/mnt/Backup) mittels rsync aus.
#
# WICHTIG: Das Skript verwendet '--sparse', um die Größe von qcow2-VM-Dateien
#          beim Kopieren nicht unnötig aufzublähen.
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

SOURCE_DIR="/var/lib/libvirt"
BACKUP_TARGET="/mnt/Backup/libvirt"
LOG_FILE="/var/log/backup_ssd.log"

echo "=== BACKUP-PROZESS GESTARTET: $(date) ===" | tee -a "$LOG_FILE"

# Prüfen, ob das Backup-Target gemountet ist
if ! mountpoint -q /mnt/Backup; then
  echo "Fehler: Backup-Laufwerk /mnt/Backup ist nicht gemountet!" | tee -a "$LOG_FILE"
  exit 1
fi

# Erstelle Zielordner falls nicht vorhanden
mkdir -p "$BACKUP_TARGET"

echo "Synchronisiere $SOURCE_DIR nach $BACKUP_TARGET..." | tee -a "$LOG_FILE"

# rsync Optionen:
#   -a: Archiv-Modus (erhält Rechte, Times, Symlinks, etc.)
#   -H: Erhält Hardlinks
#   -A: Erhält ACLs
#   -X: Erhält Extended Attributes
#   -x: Begrenzung auf ein Dateisystem (verhindert das Folgen von Mounts)
#   --sparse: Optimiert das Kopieren von spärlich belegten Dateien (qcow2)
#   --delete: Löscht im Ziel gelöschte Dateien aus der Quelle
#   --numeric-ids: Verhindert Namensauflösung der UIDs/GIDs
rsync -aHAXx \
  --sparse \
  --delete \
  --numeric-ids \
  --info=progress2 \
  "$SOURCE_DIR/" "$BACKUP_TARGET/" >> "$LOG_FILE" 2>&1

RSYNC_STATUS=$?

if [ $RSYNC_STATUS -eq 0 ]; then
  echo "=== BACKUP ERFOLGREICH BEENDET: $(date) ===" | tee -a "$LOG_FILE"
else
  echo "=== FEHLER BEIM BACKUP (Code: $RSYNC_STATUS): $(date) ===" | tee -a "$LOG_FILE"
  exit $RSYNC_STATUS
fi
