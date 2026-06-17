#!/usr/bin/env bash

# ==============================================================================
# Skript: Setup_NVMe.sh
# Beschreibung: Partitioniert die NVMe-SSD (/dev/nvme0n1), formatiert die 
#               EFI- und Btrfs-Partitionen und legt die Btrfs-Subvolumes 
#               gemäß der SOLL-Architektur an.
#
# WICHTIG: Dieses Skript löscht alle vorhandenen Daten auf /dev/nvme0n1!
# Voraussetzungen: 'sgdisk', 'dosfstools' (für mkfs.fat) und 'btrfs-progs'
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

echo "ACHTUNG: Alle Daten auf /dev/nvme0n1 werden unwiderruflich gelöscht!"
read -p "Bist du sicher, dass du fortfahren möchtest? (y/N): " confirm
if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
  echo "Setup abgebrochen."
  exit 1
fi

echo "1. Entferne alte Partitionstabellen und Signaturen auf /dev/nvme0n1..."
wipefs -a -f /dev/nvme0n1
sgdisk --zap-all /dev/nvme0n1

echo "2. Lege neue Partitionen an..."
# Partition 1: EFI System Partition (2 GiB)
sgdisk -n 1:0:+2G -t 1:ef00 -c 1:"EFI System Partition" /dev/nvme0n1

# Wir überspringen Partition 2, um der SOLL-Architektur (/dev/nvme0n1p3) exakt zu entsprechen
# Partition 3: Btrfs Root (Restlicher Speicherplatz)
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Linux Root" /dev/nvme0n1

# Dem Kernel Zeit geben, die neuen Partitionen zu registrieren
partprobe /dev/nvme0n1
sleep 2

echo "3. Formatiere die Partitionen..."
# FAT32 für EFI (Label passend zur SOLL-fstab)
mkfs.fat -F 32 -n "00CF-12A3" /dev/nvme0n1p1

# Btrfs für Root
mkfs.btrfs -f -L nvme_root /dev/nvme0n1p3

echo "4. Erstelle Btrfs-Subvolumes auf /dev/nvme0n1p3..."
mkdir -p /mnt/nvme_temp
mount /dev/nvme0n1p3 /mnt/nvme_temp

btrfs subvolume create /mnt/nvme_temp/@
btrfs subvolume create /mnt/nvme_temp/@.snapshots
btrfs subvolume create /mnt/nvme_temp/@cache

umount /mnt/nvme_temp
rmdir /mnt/nvme_temp

echo "=== NVMe SETUP ABGESCHLOSSEN ==="
echo "Die EFI-Partition und Btrfs-Subvolumes (@, @.snapshots, @cache) sind nun bereit."