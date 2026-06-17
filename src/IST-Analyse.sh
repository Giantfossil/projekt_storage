#!/bin/bash

# ==============================================================================
# Skript: IST-Analyse.sh
# Beschreibung: Sammelt reine Hardware-Informationen zu physischen Festplatten,
#               ohne Abstraktionsschichten (wie RAID, LVM, Partitionen oder bcache).
# Autor: Gemini Code Assist
# ==============================================================================

# Prüfen, ob das Skript mit Root-Rechten ausgeführt wird (notwendig für lspci)
if [[ $EUID -ne 0 ]]; then
   echo "Dieses Skript muss als root ausgeführt werden (z.B. mit sudo)." 
   exit 1
fi

LOG_FILE="./docs/logs/IST-Analyse.md"

# Verzeichnis erstellen, falls es noch nicht existiert
mkdir -p "$(dirname "$LOG_FILE")"

# Funktion für die Abfragen definieren (verhindert doppelten Code)
gather_info() {
    echo "=========================================="
    echo "=== Physische Festplatten (lsblk) ==="
    echo "=========================================="
    # lsblk mit Parameter -d (--nodeps) zeigt nur die physischen Geräte ohne Partitionen oder Abstraktionen an.
    # -e 7,11 ignoriert loop- und cdrom-Geräte.
    lsblk -d -e 7,11 -o NAME,SIZE,MODEL,SERIAL,ROTA,PHY-SEC,LOG-SEC
    echo ""

    echo "=========================================="
    echo "=== PCIe-Schnittstellen (Anbindung) ==="
    echo "=========================================="
    # Sucht nach NVMe- und SATA-Controllern auf dem PCIe-Bus und gibt deren Link-Status aus
    for pci_id in $(lspci -D | grep -iE "Non-Volatile memory controller|SATA controller" | awk '{print $1}'); do
        echo "--- PCIe-Gerät: $pci_id ---"
        # Gibt den Namen des Controllers aus
        lspci -s "$pci_id"
        # Liest Link Capabilities (LnkCap) und Link Status (LnkSta) für PCIe-Lanes und Geschwindigkeit aus
        lspci -vv -s "$pci_id" 2>/dev/null | grep -E "LnkCap:|LnkSta:" | sed 's/^[ \t]*//'
        echo ""
    done
}

# 1. Ausgabe auf dem Terminal
gather_info

# 2. Ausgabe als sauberes Markdown in die Logdatei schreiben
echo "# IST-Analyse der Hardware und Schnittstellen" > "$LOG_FILE"
echo '```text' >> "$LOG_FILE"
gather_info >> "$LOG_FILE"
echo '```' >> "$LOG_FILE"
