#!/usr/bin/env bash

# ==============================================================================
# Skript: Setup_Docker.sh
# Beschreibung: Installiert und konfiguriert Docker unter Arch Linux. 
#               Stellt sicher, dass das Docker-Verzeichnis '/var/lib/docker' 
#               (als Btrfs-Subvolume '@docker' auf dem RAID1/Bcache-Verbund) 
#               die optimalen Btrfs-Eigenschaften besitzt (nodatacow) und 
#               konfiguriert Docker für den nativen 'btrfs'-Storage-Driver.
#
# WICHTIG: Dieses Skript führt Systemänderungen durch und muss als Root / mit sudo
#          ausgeführt werden (nachdem das RAID1/Bcache-Subvolume eingehängt ist).
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

echo "1. Installiere Docker (Pacman)..."
pacman -S --needed --noconfirm docker

echo "2. Konfiguriere Benutzergruppen für 'giant'..."
# Fügt den Benutzer 'giant' zur Gruppe 'docker' hinzu, um Docker ohne sudo auszuführen
usermod -aG docker giant

echo "3. Btrfs-Optimierung: No-CoW (nodatacow) für Docker-Verzeichnis erzwingen..."
# Die fstab-Mountoption 'nodatacow' verhindert bereits standardmäßig das Copy-on-Write
# für neue Dateien auf dem Subvolume. Zur Sicherheit und Vollständigkeit setzen wir
# zusätzlich das Dateiattribut 'C' (No-CoW) auf das Verzeichnis, bevor Daten geschrieben werden.
mkdir -p /var/lib/docker
if [ -d "/var/lib/docker" ]; then
    echo "Setze 'chattr +C' (No-CoW) für /var/lib/docker..."
    chattr +C /var/lib/docker
fi

echo "4. Erstelle Docker-Konfigurationsdatei (/etc/docker/daemon.json)..."
# Da /var/lib/docker auf einem Btrfs-Dateisystem liegt, konfigurieren wir Docker 
# so, dass es den hocheffizienten, nativen 'btrfs'-Speichertreiber verwendet.
# Dies ermöglicht Docker, containerisierte Layer als native Btrfs-Subvolumes/Snapshots
# anzulegen und verhindert die Performance-Nachteile von overlay2 auf Btrfs.
mkdir -p /etc/docker
cat << 'EOF' > /etc/docker/daemon.json
{
  "storage-driver": "btrfs"
}
EOF

echo "5. Aktiviere und starte den Docker-Dienst..."
systemctl enable --now docker.service

echo "=== DOCKER SETUP ABGESCHLOSSEN ==="
echo "Benutzer 'giant' wurde zur Gruppe 'docker' hinzugefügt."
echo "Der Systemd-Dienst 'docker' wurde gestartet und auf den 'btrfs'-Treiber konfiguriert."
echo "Bitte melde dich einmal ab und wieder an, damit die Gruppenänderungen aktiv werden."
