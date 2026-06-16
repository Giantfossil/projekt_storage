#!/usr/bin/env bash

# ==============================================================================
# Skript: Build_Time_Messung.sh
# Beschreibung: Führt eine Build-Zeitmessung (C-Kompilierung) durch und 
#               analysiert die Caching-Effizienz (ccache).
# ==============================================================================

LOG_DIR="$(pwd)/docs/logs"
LOG_BASE="Build-Messung"
LOG_EXT=".md"
LOG_FILE="$LOG_DIR/${LOG_BASE}${LOG_EXT}"

# Fortlaufende Nummerierung, falls die Datei bereits existiert
if [[ -f "$LOG_FILE" ]]; then
    counter=1
    while [[ -f "$LOG_DIR/${LOG_BASE}-${counter}${LOG_EXT}" ]]; do
        ((counter++))
    done
    LOG_FILE="$LOG_DIR/${LOG_BASE}-${counter}${LOG_EXT}"
fi

# Log-Verzeichnis erstellen, falls es noch nicht existiert
mkdir -p "$LOG_DIR"

# Prüfen, ob wir uns in einem Verzeichnis mit einem Makefile befinden
if [ ! -f "Makefile" ] && [ ! -f "makefile" ]; then
    echo "Fehler: Kein Makefile im aktuellen Verzeichnis gefunden."
    echo "Bitte wechsle in das zu kompilierende Projektverzeichnis und führe das Skript dort aus."
    exit 1
fi

# Prüfen, ob ccache installiert ist
if ! command -v ccache &> /dev/null; then
    echo "Fehler: 'ccache' ist nicht installiert."
    exit 1
fi

# Cache- und Build-Verzeichnisse konfigurieren
export CCACHE_DIR="$HOME/.cache/ccache"
BUILD_DIR="$HOME/.cache/build"

mkdir -p "$CCACHE_DIR"

# Build-Verzeichnis leeren und Projektdateien dorthin kopieren
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
echo "Kopiere Projektdateien nach $BUILD_DIR..."
cp -aT . "$BUILD_DIR"

# Ins Build-Verzeichnis wechseln für den sauberen Build-Prozess
cd "$BUILD_DIR" || { echo "Fehler beim Wechsel in das Build-Verzeichnis"; exit 1; }

echo "Starte Build-Messung. Ergebnisse werden in $LOG_FILE gespeichert..."

# Markdown-Kopf in die Datei schreiben
echo "# Build-Zeitmessung und Cache-Analyse" > "$LOG_FILE"

echo "## 1. Durchgang (Initialer Build)" >> "$LOG_FILE"
echo '```text' >> "$LOG_FILE"
echo "--- ccache Status (Vorher) ---" >> "$LOG_FILE"
ccache -s >> "$LOG_FILE" 2>&1

echo -e "\n--- Build (make) ---" >> "$LOG_FILE"
make clean &>/dev/null
{ time make -j$(nproc); } >> "$LOG_FILE" 2>&1
echo '```' >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "## 2. Durchgang (Build mit gefülltem Cache)" >> "$LOG_FILE"
echo '```text' >> "$LOG_FILE"
echo "--- Build (make) ---" >> "$LOG_FILE"
make clean &>/dev/null
{ time make -j$(nproc); } >> "$LOG_FILE" 2>&1

echo -e "\n--- ccache Status (Nachher) ---" >> "$LOG_FILE"
ccache -s >> "$LOG_FILE" 2>&1
echo '```' >> "$LOG_FILE"

echo "Messung abgeschlossen! Log wurde erfolgreich generiert."
