#!/usr/bin/env bash

# ==============================================================================
# Skript: Setup_RAID1_Bcache.sh
# Beschreibung: Richtet ein RAID1-Array (/dev/md0) aus zwei HDDs ein, konfiguriert
#               eine SATA-SSD als Bcache-Caching-Device (/dev/sda), richtet
#               die I/O-Scheduler und Sysctl-Parameter ein und erstellt die
#               benötigten Btrfs-Subvolumes.
#
# WICHTIG: Dieses Skript löscht alle Daten auf /dev/sda, /dev/sdb und /dev/sdd!
# Voraussetzungen: 'mdadm' und 'bcache-tools' müssen installiert sein.
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

echo "ACHTUNG: Alle Daten auf /dev/sda, /dev/sdb und /dev/sdd werden unwiderruflich gelöscht!"
read -p "Bist du sicher, dass du fortfahren möchtest? (y/N): " confirm
if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
  echo "Setup abgebrochen."
  exit 1
fi

echo "1. Entferne alte Dateisystem-Signaturen..."
wipefs -a -f /dev/sda
wipefs -a -f /dev/sdb
wipefs -a -f /dev/sdd

echo "2. Erstelle RAID1 (/dev/md0)..."
# --run unterdrückt interaktive Prompts, --chunk=512 optimiert für 512e
mdadm --create --run /dev/md0 \
  --level=1 \
  --raid-devices=2 \
  --chunk=512 \
  /dev/sdb /dev/sdd

# Kurz warten, bis der Kernel md0 sauber registriert hat
sleep 3

echo "3. Richte Bcache ein (/dev/sda als Cache, /dev/md0 als Backing-Device)..."
make-bcache -B /dev/md0 -C /dev/sda

# Kurz warten, bis das bcache0 Device zur Verfügung steht
sleep 3

# Caching-Modus auf 'writeback' setzen, um nicht nur Lese-, sondern auch Schreibvorgänge zu cachen
if [ -e /sys/block/bcache0/bcache/cache_mode ]; then
    echo writeback > /sys/block/bcache0/bcache/cache_mode
fi

echo "4. Formatiere das Bcache-Device mit Btrfs..."
mkfs.btrfs -f -L md0_home /dev/bcache0

echo "5. Erstelle Btrfs-Subvolumes auf dem neuen RAID/Bcache-Verbund..."
mkdir -p /mnt/bcache_temp
mount /dev/bcache0 /mnt/bcache_temp

btrfs subvolume create /mnt/bcache_temp/@home
btrfs subvolume create /mnt/bcache_temp/@home_snapshots
btrfs subvolume create /mnt/bcache_temp/@docker
btrfs subvolume create /mnt/bcache_temp/@_snapshots

umount /mnt/bcache_temp
rmdir /mnt/bcache_temp

echo "6. Erstelle udev-Regeln für I/O-Scheduler und Read-Ahead..."
cat << 'EOF' > /etc/udev/rules.d/60-io-scheduler.rules
# SATA SSD (sdc) — mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", \
  ATTR{queue/scheduler}="mq-deadline", \
  ATTR{queue/nr_requests}="32", \
  ATTR{queue/read_ahead_kb}="256"

# HDD (sdb, sdd — md0 Member) — bfq
ACTION=="add|change", KERNEL=="sd[bd]", ATTR{queue/rotational}=="1", \
  ATTR{queue/scheduler}="bfq", \
  ATTR{queue/read_ahead_kb}="2048"

# RAID1 (md0) — Read-Ahead Erhöhung auf md-Ebene
ACTION=="add|change", KERNEL=="md0", ATTR{queue/read_ahead_kb}="4096"
EOF

echo "7. Erstelle sysctl-Parameter für I/O & RAID1-Sync..."
cat << 'EOF' > /etc/sysctl.d/60-io.conf
# Dirty-Page-Verhältnis
vm.dirty_ratio = 10
vm.dirty_background_ratio = 3

# Writeback-Intervall
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 1500

# Swappiness
vm.swappiness = 10

# VFS Cache Pressure
vm.vfs_cache_pressure = 100

# RAID1 Resync Limits (in KiB/s)
dev.raid.speed_limit_min = 50000
dev.raid.speed_limit_max = 200000
EOF

echo "8. Wende Kernel-Konfigurationen an..."
udevadm control --reload-rules
udevadm trigger --type=devices --action=change
sysctl --system

echo "=== SETUP ABGESCHLOSSEN ==="
echo "RAID1 (/dev/md0) und Bcache (/dev/bcache0) sind nun konfiguriert und einsatzbereit!"