#!/usr/bin/env bash

# ==============================================================================
# Skript: Setup_fstrim.sh
# Beschreibung: Aktiviert den systemd-Timer für fstrim (wöchentlicher TRIM-
#               Befehl für alle passenden gemounteten SSDs/NVMes), um die 
#               Performance und Lebensdauer der Flash-Speicher zu erhalten.
# Voraussetzungen: 'util-linux' (enthält fstrim und den systemd-Service)
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

echo "Aktivieren des wöchentlichen fstrim.timer..."

# Den Timer aktivieren und sofort starten
systemctl enable --now fstrim.timer

# Status überprüfen
if systemctl is-active --quiet fstrim.timer; then
    echo "fstrim.timer wurde erfolgreich aktiviert!"
    systemctl status fstrim.timer --no-pager
else
    echo "Fehler beim Aktivieren von fstrim.timer."
    exit 1
fi

echo "=== fstrim SETUP ABGESCHLOSSEN ==="