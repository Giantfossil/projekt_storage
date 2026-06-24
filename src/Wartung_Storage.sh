#!/usr/bin/env bash

# ==============================================================================
# Skript: Wartung_Storage.sh
# Beschreibung: Automatisches Wartungsskript für die Btrfs- und XFS-Dateisysteme.
#               Führt Integritätsprüfungen (Scrub), Datenbereinigungen (Balance)
#               und Defragmentierungen (Btrfs defrag / xfs_fsr) durch.
#
# WICHTIG: Die Ausführung dieses Skripts erfordert Root-Rechte und erzeugt I/O-Last.
#          Es dient der Systempflege und wird im Rahmen der Phase 4 ausgeführt.
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

LOG_FILE="/var/log/storage_wartung.log"
exec > >(tee -ia "$LOG_FILE") 2>&1

echo "=============================================================================="
echo "SPEICHER-WARTUNG GESTARTET: $(date)"
echo "=============================================================================="

# --- 1. Btrfs Scrub (Integritätsprüfung) ---
# Startet einen Scrub im Vordergrund (-B) für alle Btrfs-Dateisysteme.
# Ein Scrub vergleicht Datenblöcke mit ihren Prüfsummen und repariert sie im RAID1 automatisch.

echo -e "\n[1/4] Starte Btrfs Scrub auf '/' (NVMe)..."
btrfs scrub start -B /

echo -e "\n[1/4] Starte Btrfs Scrub auf '/home' (RAID1 + Bcache)..."
btrfs scrub start -B /home


# --- 2. Btrfs Balance (Datenbereinigung) ---
# Bereinigt nicht vollständig belegte Chunks (Daten und Metadaten), um Speicherplatz 
# freizugeben und dem Fehler 'No space left on device' vorzubeugen.
# Wir filtern nach usage=50 (bearbeitet nur Chunks, die zu weniger als 50% belegt sind).

echo -e "\n[2/4] Starte Btrfs Balance auf '/' (Filter: dusage=50, musage=50)..."
# -dusage: Daten-Chunks, -musage: Metadaten-Chunks
btrfs balance start -dusage=50 -musage=50 / || echo "Keine Anpassung nötig oder übersprungen."

echo -e "\n[2/4] Starte Btrfs Balance auf '/home' (Filter: dusage=50, musage=50)..."
btrfs balance start -dusage=50 -musage=50 /home || echo "Keine Anpassung nötig oder übersprungen."


# --- 3. Btrfs Defragmentierung ---
# Defragmentiert gezielt Verzeichnisse, die Copy-on-Write-Fragmentierung aufweisen.
# (Systemdaten und Cache-Verzeichnisse auf dem Root-Dateisystem).
# Hinweis: /var/lib/docker und Caches liegen auf nodatacow-Subvolumes oder XFS, 
# weshalb hier nur das Standard-Systemverzeichnis defragmentiert wird.

echo -e "\n[3/4] Starte Btrfs Defragmentierung auf '/' (systemrelevante Pfade)..."
btrfs filesystem defragment -r -clzo /bin /sbin /usr /lib


# --- 4. XFS Defragmentierung (xfs_fsr) ---
# 'xfs_fsr' (File System Reorganizer) defragmentiert XFS-Dateisysteme online.
# Dies sichert die Performance der Caches und VM-Images auf der SATA SSD.

echo -e "\n[4/4] Starte XFS Defragmentierung auf '/dev/sdc'-Partitionen..."
XFS_MOUNTS=("/var/lib/libvirt" "/var/log" "/var/cache/build" "/var/cache/ccache")

for mountpoint in "${XFS_MOUNTS[@]}"; do
  if mountpoint -q "$mountpoint"; then
    echo "Defragmentiere $mountpoint..."
    # xfs_fsr läuft standardmäßig für maximal 2 Stunden pro Dateisystem (kann verkürzt werden)
    xfs_fsr -v "$mountpoint"
  else
    echo "Überspringe $mountpoint (nicht gemountet)."
  fi
done

echo -e "\n=============================================================================="
echo "SPEICHER-WARTUNG BEENDET: $(date)"
echo "Log-Protokoll gesichert unter: $LOG_FILE"
echo "=============================================================================="
