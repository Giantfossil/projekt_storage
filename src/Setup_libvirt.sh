#!/usr/bin/env bash

# ==============================================================================
# Skript: Setup_libvirt.sh
# Beschreibung: Richtet die Virtualisierungsumgebung (KVM, QEMU, libvirt) unter
#               Arch Linux ein. Konfiguriert Berechtigungen, Systemd-Dienste,
#               das Standard-Netzwerk und optimiert die I/O-Latenz für den
#               Mountpoint '/var/lib/libvirt' (auf /dev/sdc1).
#
# WICHTIG: Dieses Skript führt Systemänderungen durch und muss als Root / mit sudo
#          ausgeführt werden (nachdem das SSD-Mountpoint /var/lib/libvirt aktiv ist).
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

echo "1. Installiere benötigte Virtualisierungs-Pakete (Pacman)..."
# pacman -S --needed installiert nur nicht-vorhandene Pakete
pacman -S --needed --noconfirm \
  qemu-desktop \
  libvirt \
  virt-manager \
  dnsmasq \
  iptables-nft \
  dmidecode

echo "2. Konfiguriere Benutzergruppen für 'giant'..."
# Fügt den Benutzer 'giant' zu den Gruppen 'libvirt' und 'kvm' hinzu
usermod -aG libvirt giant
usermod -aG kvm giant

echo "3. Richte die Berechtigungen für das VM-Image-Verzeichnis (/var/lib/libvirt) ein..."
# Damit QEMU/KVM-Prozesse (die oft unter dem User 'qemu' laufen) auf die SSD-Partition
# zugreifen können, müssen die Gruppenrechte auf 'kvm' gesetzt und Schreibrechte erteilt werden.
chown root:kvm /var/lib/libvirt
chmod 775 /var/lib/libvirt

# Sicherstellen, dass auch der Images-Unterordner existiert und Rechte passen
mkdir -p /var/lib/libvirt/images
chown root:kvm /var/lib/libvirt/images
chmod 775 /var/lib/libvirt/images

echo "4. Aktiviere und starte den libvirtd-Dienst..."
systemctl enable --now libvirtd.service

# Kurze Pause zum Starten des Daemons
sleep 2

echo "5. Konfiguriere das Standard-NAT-Netzwerk (default)..."
# Startet das Default-Netzwerk und stellt sicher, dass es bei jedem Boot gestartet wird
virsh net-start default 2>/dev/null || echo "Default-Netzwerk läuft bereits."
virsh net-autostart default

echo "6. Optimierung der I/O-Einstellungen für die VM-Partition (/dev/sdc1)..."
# Um den Read-Ahead-Wert spezifisch für die VM-Image-Partition auf 1024 KiB zu erhöhen,
# fügen wir eine udev-Regel hinzu, die blockdev für die Partition ausführt.
UDEV_RULES_FILE="/etc/udev/rules.d/60-io-scheduler.rules"

if [ -f "$UDEV_RULES_FILE" ]; then
  if ! grep -q "sdc1" "$UDEV_RULES_FILE"; then
    echo "Füge spezifischen Partition-Read-Ahead für sdc1 zu den udev-Regeln hinzu..."
    cat << 'EOF' >> "$UDEV_RULES_FILE"

# SATA SSD Partition 1 (sdc1 — libvirt) — Erhöhter Read-Ahead für qcow2-VM-Images
ACTION=="add|change", KERNEL=="sdc1", RUN+="/usr/bin/blockdev --setra 2048 %N"
EOF
    # udev-Regeln neu laden
    udevadm control --reload-rules
    udevadm trigger --type=devices --action=change
  fi
else
  echo "Warnung: $UDEV_RULES_FILE nicht gefunden. Die udev-Regel für sdc1 wurde nicht geschrieben."
fi

echo "=== LIBVIRT SETUP ABGESCHLOSSEN ==="
echo "Benutzer 'giant' wurde zu den Gruppen 'libvirt' und 'kvm' hinzugefügt."
echo "Der Systemd-Dienst 'libvirtd' und das Default-Netzwerk wurden gestartet."
echo "Bitte melde dich einmal ab und wieder an, damit die Gruppenänderungen aktiv werden."
