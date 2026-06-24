#!/usr/bin/env bash

# ==============================================================================
# Skript: Setup_ccache.sh
# Beschreibung: Richtet die ccache-Konfigurationsdatei und die benötigten 
#               Umgebungsvariablen für ccache, Rust (cargo) und Python (pip) 
#               im Benutzerprofil ein.
#
# WICHTIG: Dieses Skript führt Änderungen in '~/.bashrc' und '~/.config/ccache/'
#          für den aktuellen Benutzer aus.
# ==============================================================================

USER_HOME="/home/giant"
CCACHE_CONF_DIR="$USER_HOME/.config/ccache"
CCACHE_CONF_FILE="$CCACHE_CONF_DIR/ccache.conf"
BASHRC_FILE="$USER_HOME/.bashrc"

echo "1. Erstelle ccache-Konfigurationsverzeichnis..."
mkdir -p "$CCACHE_CONF_DIR"

echo "2. Schreibe ccache.conf..."
cat << 'EOF' > "$CCACHE_CONF_FILE"
# ccache-Konfiguration
cache_dir = /home/giant/.cache/ccache
max_size = 45.0G
EOF

# Rechte für giant anpassen
chown -R giant:giant "$CCACHE_CONF_DIR"

echo "3. Richte Umgebungsvariablen in .bashrc ein..."
# Prüfen, ob die Variablen bereits existieren, um Doppeleinträge zu vermeiden
VARIABLES=(
  "export XDG_CONFIG_HOME=\"\$HOME/.config\""
  "export XDG_DATA_HOME=\"\$HOME/.local/share\""
  "export XDG_STATE_HOME=\"\$HOME/.local/state\""
  "export XDG_CACHE_HOME=\"\$HOME/.cache\""
  "export CCACHE_DIR=\"\$HOME/.cache/ccache\""
  "export CARGO_HOME=\"\$HOME/.cache/build/cargo\""
  "export PIP_CACHE_DIR=\"\$HOME/.cache/build/pip\""
)

echo -e "\n# --- Storage Projekt Umgebungsvariablen ---" >> "$BASHRC_FILE"
for var in "${VARIABLES[@]}"; do
  if grep -Fxq "$var" "$BASHRC_FILE"; then
    echo "Variable '$var' existiert bereits in .bashrc, überspringe..."
  else
    echo "Füge hinzu: $var"
    echo "$var" >> "$BASHRC_FILE"
  fi
done

echo "=== CCACHE SETUP ABGESCHLOSSEN ==="
echo "Konfiguration unter '$CCACHE_CONF_FILE' wurde angelegt."
echo "Umgebungsvariablen wurden in '$BASHRC_FILE' eingetragen."
echo "Bitte führe 'source ~/.bashrc' aus, um die Änderungen im aktuellen Terminal zu laden."
