#!/usr/bin/env bash

# ==============================================================================
# Skript: Healthcheck_Messung.sh
# Beschreibung: Führt eine umfassende System- und Speicher-Diagnose durch.
#               Überprüft SMART-Werte, RAID1-Status, Bcache-Zustand, 
#               Btrfs-Fehlerzähler und Speicherbelegung.
#               Ergebnisse werden als Markdown-Bericht exportiert.
#
# WICHTIG: Dieses Skript benötigt Root-Rechte (für smartctl & btrfs stats).
#          Es darf NICHT direkt ausgeführt werden, sondern dient der
#          Vorbereitung und Dokumentation.
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

LOG_DIR="$(pwd)/docs/logs"
LOG_FILE="$LOG_DIR/Healthcheck_Bericht.md"
mkdir -p "$LOG_DIR"

echo "Starte Speicher-Healthcheck. Bericht wird geschrieben nach: $LOG_FILE"

# Markdown-Header schreiben
cat << 'EOF' > "$LOG_FILE"
# Speicher-Healthcheck & Diagnoseprotokoll
Generiert am: UTC-Zeit (automatisch generiert bei Ausführung)

Dieses Protokoll fasst den Gesundheitszustand der physischen und logischen Datenträger zusammen.

---

## 1. Systemübersicht & Speicherbelegung
```text
EOF

df -hT -x devtmpfs -x tmpfs >> "$LOG_FILE"

cat << 'EOF' >> "$LOG_FILE"
```

---

## 2. RAID1-Status (/dev/md0)
```text
EOF

if [ -e /proc/mdstat ]; then
    cat /proc/mdstat >> "$LOG_FILE"
    echo -e "\n--- Details ---" >> "$LOG_FILE"
    mdadm --detail /dev/md0 2>/dev/null >> "$LOG_FILE" || echo "md0 nicht aktiv." >> "$LOG_FILE"
else
    echo "Kein Software-RAID vorhanden (/proc/mdstat existiert nicht)." >> "$LOG_FILE"
fi

cat << 'EOF' >> "$LOG_FILE"
```

---

## 3. Bcache-Status (/dev/bcache0)
```text
EOF

if [ -d /sys/block/bcache0 ]; then
    echo "Cache-Modus: $(cat /sys/block/bcache0/bcache/cache_mode)" >> "$LOG_FILE"
    echo "Zustand:     $(cat /sys/block/bcache0/bcache/state)" >> "$LOG_FILE"
    echo "Dirty Data:  $(cat /sys/block/bcache0/bcache/dirty_data 2>/dev/null)" >> "$LOG_FILE"
    
    # Cache-UUID herausfinden
    CACHE_UUID=$(ls -d /sys/fs/bcache/* 2>/dev/null | head -n 1 | awk -F/ '{print $NF}')
    if [ -n "$CACHE_UUID" ] && [ -d "/sys/fs/bcache/$CACHE_UUID" ]; then
        echo "Cache-Verfügbarkeit: $(cat /sys/fs/bcache/$CACHE_UUID/cache_available_percent)%" >> "$LOG_FILE"
    fi
else
    echo "Kein Bcache-Device (/dev/bcache0) aktiv." >> "$LOG_FILE"
fi

cat << 'EOF' >> "$LOG_FILE"
```

---

## 4. Btrfs-Fehlerstatistiken (Device Stats)
Hier werden E/A- und Datenkorruptions-Fehlerzähler von Btrfs abgefragt. Alle Werte sollten idealerweise 0 sein.

```text
EOF

echo "--- Subvolume / (Root) ---" >> "$LOG_FILE"
btrfs device stats / 2>/dev/null >> "$LOG_FILE" || echo "Nicht als Btrfs gemountet oder Fehler." >> "$LOG_FILE"

echo -e "\n--- Subvolume /home ---" >> "$LOG_FILE"
btrfs device stats /home 2>/dev/null >> "$LOG_FILE" || echo "Nicht als Btrfs gemountet oder Fehler." >> "$LOG_FILE"

cat << 'EOF' >> "$LOG_FILE"
```

---

## 5. SMART-Gesundheitsstatus (Physical Drives)
Abfrage des SMART-Selbsttests für alle im System integrierten Laufwerke.

| Datenträger | Verwendung | SMART-Status |
| :--- | :--- | :--- |
EOF

DEVICES=(
  "/dev/nvme0n1:OS (Crucial NVMe)"
  "/dev/sda:Bcache-SSD (Samsung 850 EVO)"
  "/dev/sdb:RAID1 Member HDD (Seagate)"
  "/dev/sdc:Workload-SSD (Samsung 850 PRO)"
  "/dev/sdd:RAID1 Member HDD (Toshiba)"
)

for dev_info in "${DEVICES[@]}"; do
  DEV=$(echo "$dev_info" | cut -d: -f1)
  DESC=$(echo "$dev_info" | cut -d: -f2)
  
  if [ -b "$DEV" ]; then
    # Testen, ob NVMe oder SATA
    if [[ "$DEV" == *nvme* ]]; then
      SMART_STATUS=$(smartctl -H "$DEV" 2>/dev/null | grep -i "SMART overall-health" | awk -F: '{print $2}' | xargs)
    else
      SMART_STATUS=$(smartctl -H "$DEV" 2>/dev/null | grep -i "test result" | awk -F: '{print $2}' | xargs)
    fi
    
    if [ -z "$SMART_STATUS" ]; then
      SMART_STATUS="Unbekannt (smartctl-Fehler)"
    fi
  else
    SMART_STATUS="Nicht gefunden"
  fi
  
  echo "| \`$DEV\` | $DESC | **$SMART_STATUS** |" >> "$LOG_FILE"
done

echo -e "\nDiagnosebericht wurde erfolgreich erstellt."
