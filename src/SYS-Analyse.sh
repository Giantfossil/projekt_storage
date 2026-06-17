#!/usr/bin/env bash

# ==============================================================================
# Skript: SYS-Analyse.sh
# Beschreibung: Analysiert und gibt grundlegende System- und Speicherinformationen aus.
# ==============================================================================

# Prüfen, ob inxi installiert ist
if ! command -v inxi &> /dev/null; then
    echo "Fehler: 'inxi' ist nicht installiert. Bitte installiere es (z.B. mit 'sudo pacman -S inxi')."
    exit 1
fi

echo "=========================================="
echo "=== System- und Storage-Analyse (inxi) ==="
echo "=========================================="
# inxi Parameter-Erklärung:
# -S : Systeminformationen (Host, Kernel, Desktop etc.)
# -D : Festplatten/Datenträger
# -R : Software-RAID-Informationen
# -m : Arbeitsspeicher (Memory)
# -j : Swap-Informationen
# -xx: Erhöhte Detailstufe (Verbosity Level 2)

# Pfad zur Markdown-Logdatei
LOG_FILE="./doc/logs/Systeminformationen.md"

# Verzeichnis erstellen, falls es noch nicht existiert
mkdir -p "$(dirname "$LOG_FILE")"

# 1. Ausgabe auf dem Terminal (mit Standard-Farben)
inxi -S -D -R -m -j -xx

# 2. Ausgabe als sauberes Markdown in die Datei schreiben (Farbcodes mit -c 0 deaktiviert)
echo "# System- und Storage-Informationen" > "$LOG_FILE"
echo '```text' >> "$LOG_FILE"
inxi -S -D -R -m -j -xx -c 0 >> "$LOG_FILE"
echo '```' >> "$LOG_FILE"

echo ""