#!/usr/bin/env bash

# ==============================================================================
# Skript: Setup_SSD.sh
# Beschreibung: Partitioniert die SATA SSD (/dev/sdc), formatiert die Partitionen
#               mit optimierten XFS-Optionen (gemäß docs/SOLL-Architektur.md und
#               src/Messungen/build_messung.md), erstellt die Mountpoints und 
#               setzt die Benutzerrechte für '/home/giant'.
#
# WICHTIG: Dieses Skript löscht alle vorhandenen Daten auf /dev/sdc!
#          Es darf NICHT direkt ausgeführt werden, sondern dient der
#          Dokumentation und Vorbereitung.
# Voraussetzungen: 'sgdisk', 'xfsprogs' (für mkfs.xfs)
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

echo "ACHTUNG: Alle Daten auf /dev/sdc werden unwiderruflich gelöscht!"
read -p "Bist du sicher, dass du fortfahren möchtest? (y/N): " confirm
if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
  echo "Setup abgebrochen."
  exit 1
fi

echo "1. Entferne alte Partitionstabellen und Signaturen auf /dev/sdc..."
wipefs -a -f /dev/sdc
sgdisk --zap-all /dev/sdc

echo "2. Lege neue Partitionen auf /dev/sdc an..."
# Partition 1: libvirt (200 GiB)
sgdisk -n 1:0:+200G -t 1:8300 -c 1:"libvirt" /dev/sdc

# Partition 2: logs (30 GiB)
sgdisk -n 2:0:+30G -t 2:8300 -c 2:"logs" /dev/sdc

# Partition 3: build cache (120 GiB)
sgdisk -n 3:0:+120G -t 3:8300 -c 3:"build" /dev/sdc

# Partition 4: ccache (50 GiB)
sgdisk -n 4:0:+50G -t 4:8300 -c 4:"ccache" /dev/sdc

# Der Rest (~112 GiB bei einer 512GB SSD) bleibt unpartitioniert / Reserve,
# um XFS-Fragmentierung bei hoher Belegung (>90%) zu verhindern.

# Dem Kernel Zeit geben, die neuen Partitionen zu registrieren
partprobe /dev/sdc
sleep 2

echo "3. Formatiere die Partitionen mit XFS..."
# Partition 1 (libvirt): Optimiert für große VM-Images (agcount=2, log size=128m)
mkfs.xfs -f -L libvirt -d agcount=2 -l size=128m /dev/sdc1

# Partition 2 (logs): Reduzierte Log-Größe (size=32m) für Metadaten-Journaling
mkfs.xfs -f -L logs -l size=32m /dev/sdc2

# Partitionen 3 & 4 (build & ccache): Standard block size = 4096
mkfs.xfs -f -L build -b size=4096 /dev/sdc3
mkfs.xfs -f -L ccache -b size=4096 /dev/sdc4

echo "4. Erstelle Mountpoints im System..."
mkdir -p /var/lib/libvirt
mkdir -p /var/log
mkdir -p /var/cache/build
mkdir -p /var/cache/ccache

echo "5. Erstelle Userspace-Cache-Verzeichnisse für 'giant'..."
mkdir -p /home/giant/.cache/build
mkdir -p /home/giant/.cache/ccache

echo "6. Berechtigungen anpassen..."
# Eigentumsrechte auf die Cache-Verzeichnisse für den Benutzer 'giant' übertragen
chown -R giant:giant /var/cache/build
chown -R giant:giant /var/cache/ccache
chown -R giant:giant /home/giant/.cache/build
chown -R giant:giant /home/giant/.cache/ccache

# Temporäre Ordner-Berechtigungen absichern
chmod 1777 /tmp
chmod 1777 /var/tmp

echo "=== SSD SETUP ABGESCHLOSSEN ==="
echo "Die Partitionen auf /dev/sdc sind erstellt und formatiert."
echo "Die Verzeichnisse für die Bindmounts wurden angelegt."
echo ""
echo "Bitte trage die folgenden Zeilen in deine /etc/fstab ein:"
echo "------------------------------------------------------------"
echo "LABEL=libvirt    /var/lib/libvirt   xfs  defaults,noatime,nodiratime,largeio,swalloc        0 2"
echo "LABEL=logs       /var/log           xfs  defaults,noatime,nodiratime,nodev,noexec                       0 2"
echo "LABEL=build      /var/cache/build   xfs  defaults,noatime,nodiratime,nodev,nosuid                        0 2"
echo "LABEL=ccache     /var/cache/ccache  xfs  defaults,noatime,nodiratime,nodev,nosuid                        0 2"
echo ""
echo "# Bindmounts — Userspace-Caches"
echo "/var/cache/build   /home/giant/.cache/build   none  defaults,bind,nofail,x-systemd.requires=/var/cache/build   0 0"
echo "/var/cache/ccache  /home/giant/.cache/ccache  none  defaults,bind,nofail,x-systemd.requires=/var/cache/ccache  0 0"
echo "------------------------------------------------------------"
