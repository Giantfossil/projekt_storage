#!/usr/bin/env bash

# ==============================================================================
# Skript: Messung.sh
# Beschreibung: Führt automatisierte Performance-Messungen (Benchmarks) mit 
#               'fio' auf den SSD-Partitionen (/var/lib/libvirt, /var/cache/build)
#               durch. 
#               Die Tests laufen sicher im Dateisystem ab (unter Verwendung von
#               Temporärdateien) und zerstören KEINE Partitionstabellen.
#
# WICHTIG: Das Skript erfordert 'fio' und muss als root (oder mit sudo) 
#          ausgeführt werden, da es Schreib-/Lesetests in Systemverzeichnissen 
#          durchführt. Führe es niemals direkt ohne Absprache aus.
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

if ! command -v fio &> /dev/null; then
  echo "Fehler: 'fio' ist nicht installiert. Bitte installiere es zuerst."
  exit 1
fi

LOG_DIR="$(pwd)/docs/logs"
LOG_FILE="$LOG_DIR/IO_Benchmark_Ergebnisse.md"
mkdir -p "$LOG_DIR"

echo "Starte I/O-Performance Benchmarks. Ergebnisse werden gesichert in: $LOG_FILE"

cat << 'EOF' > "$LOG_FILE"
# Speicher-Performance-Messergebnisse (fio Benchmark)
Generiert am: UTC-Zeit (automatisch generiert bei Ausführung)

Dieses Dokument erfasst die gemessenen I/O-Leistungswerte (IOPS, Bandbreite und Latenzen).

---

EOF

# --- Test 1: VM-Simulation auf /var/lib/libvirt (Mixed Random I/O, large queue) ---
VM_DIR="/var/lib/libvirt"
if mountpoint -q "$VM_DIR" || [ -d "$VM_DIR" ]; then
    echo "Führe Test 1 (VM-Simulation) auf $VM_DIR aus..."
    cat << 'EOF' >> "$LOG_FILE"
## 1. VM-Simulation auf /var/lib/libvirt (Mixed Random Read/Write)
* **Zweck:** Simuliert typische VM-Festplatten-Zugriffe (70% Read / 30% Write, 64k Blocks, IO-Tiefe 64).
* **Konfiguration:** `fio --rw=randrw --rwmixread=70 --bs=64k --size=1G --iodepth=64`

```text
EOF

    fio --name=vm-sim \
        --directory="$VM_DIR" \
        --ioengine=libaio \
        --rw=randrw --rwmixread=70 \
        --bs=64k --size=1G \
        --numjobs=2 --iodepth=64 \
        --runtime=30 --time_based \
        --end_fsync=1 >> "$LOG_FILE" 2>&1

    echo -e "```\n\n---" >> "$LOG_FILE"
else
    echo "Überspringe Test 1: $VM_DIR ist nicht gemountet/vorhanden."
fi


# --- Test 2: Build- / Cache-Simulation auf /var/cache/build (Kleine Random Writes) ---
BUILD_DIR="/var/cache/build"
if mountpoint -q "$BUILD_DIR" || [ -d "$BUILD_DIR" ]; then
    echo "Führe Test 2 (Build/Metadata) auf $BUILD_DIR aus..."
    cat << 'EOF' >> "$LOG_FILE"
## 2. Build- / Cache-Simulation auf /var/cache/build (Metadata-heavy Random Write)
* **Zweck:** Simuliert Compiler-Caches (ccache, cargo) und das Schreiben vieler kleiner Dateien (4k Blocks, IO-Tiefe 16).
* **Konfiguration:** `fio --rw=randwrite --bs=4k --size=256M --iodepth=16`

```text
EOF

    fio --name=build-sim \
        --directory="$BUILD_DIR" \
        --ioengine=libaio \
        --rw=randwrite --bs=4k \
        --size=256M --numjobs=4 \
        --iodepth=16 --runtime=30 \
        --time_based >> "$LOG_FILE" 2>&1

    echo -e "```\n\n---" >> "$LOG_FILE"
else
    echo "Überspringe Test 2: $BUILD_DIR ist nicht gemountet/vorhanden."
fi


# --- Test 3: Log-Schreiben Simulation auf /var/log (Sequentielle Appends) ---
LOGS_DIR="/var/log"
if mountpoint -q "$LOGS_DIR" || [ -d "$LOGS_DIR" ]; then
    echo "Führe Test 3 (Logs/Append) auf $LOGS_DIR aus..."
    cat << 'EOF' >> "$LOG_FILE"
## 3. Log-Schreiben Simulation auf /var/log (Sequentielle Append-Vorgänge)
* **Zweck:** Simuliert Journald/Syslog Schreibverhalten (Sequentielle Writes, sync I/O Engine, fsync nach jedem Write).
* **Konfiguration:** `fio --ioengine=sync --rw=write --bs=4k --size=100M --fsync=1`

```text
EOF

    fio --name=log-sim \
        --directory="$LOGS_DIR" \
        --ioengine=sync \
        --rw=write --bs=4k \
        --size=100M --numjobs=2 \
        --fsync=1 >> "$LOG_FILE" 2>&1

    echo -e "```\n" >> "$LOG_FILE"
else
    echo "Überspringe Test 3: $LOGS_DIR ist nicht gemountet/vorhanden."
fi

# Aufräumen von übrig gebliebenen fio-Dateien (falls vorhanden)
rm -f "$VM_DIR/vm-sim*" "$BUILD_DIR/build-sim*" "$LOGS_DIR/log-sim*"

echo "Benchmarks abgeschlossen. Ergebnisse in $LOG_FILE gesichert."
