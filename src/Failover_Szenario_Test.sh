#!/usr/bin/env bash

# ==============================================================================
# Skript: Failover_Szenario_Test.sh
# Beschreibung: Dient der Simulation und Durchführung eines Failover-Tests auf
#               dem Software-RAID1 (/dev/md0). Zeigt die genauen Befehle zur
#               Simulation eines HDD-Ausfalls, der Entfernung der Festplatte,
#               dem Partitionstransfer auf eine neue Platte und dem Rebuild.
#
# WICHTIG: Dieses Skript verringert temporär die Redundanz deines RAID1!
#          Führe es nur aus, wenn du das Failover-Szenario absichtlich testen
#          willst oder ein realer Notfall vorliegt.
#          Es darf NICHT unüberlegt ausgeführt werden.
# ==============================================================================

if [ "$EUID" -ne 0 ]; then
  echo "Bitte als root (oder mit sudo) ausführen."
  exit 1
fi

echo "=== FAILOVER SCENARIO TEST & LEITFADEN ==="
echo "Dieses Skript führt dich durch den Test eines Festplattenausfalls auf /dev/md0."
echo "Aktuelle Members des RAID1 sind /dev/sdb und /dev/sdd."
echo ""
echo "ACHTUNG: Bei Durchführung wird eine Festplatte als 'defekt' markiert und entfernt!"
read -p "Möchtest du den interaktiven Leitfaden starten? (y/N): " confirm
if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
  echo "Abgebrochen."
  exit 1
fi

# 1. Ist-Zustand anzeigen
echo -e "\n--- 1. Aktueller RAID-Zustand ---"
mdadm --detail /dev/md0
echo "Drücke ENTER um fortzufahren (simuliert Ausfall von /dev/sdb)..."
read

# 2. Ausfall simulieren
echo -e "\n--- 2. Simuliere Ausfall von /dev/sdb ---"
echo "Befehl: mdadm --manage /dev/md0 --fail /dev/sdb"
mdadm --manage /dev/md0 --fail /dev/sdb
sleep 1

echo -e "\nNeuer Zustand in /proc/mdstat (sollte degraded [U_] zeigen):"
cat /proc/mdstat
echo "Drücke ENTER um fortzufahren (entfernt die 'defekte' /dev/sdb aus dem RAID)..."
read

# 3. Festplatte entfernen
echo -e "\n--- 3. Entferne /dev/sdb aus dem RAID1-Verbund ---"
echo "Befehl: mdadm --manage /dev/md0 --remove /dev/sdb"
mdadm --manage /dev/md0 --remove /dev/sdb
sleep 1

echo -e "\nRAID-Zustand nach Entfernung:"
mdadm --detail /dev/md0
echo "Drücke ENTER um fortzufahren (stellt sdb wieder bereit und startet den Rebuild)..."
read

# 4. Partitionstabelle kopieren
echo -e "\n--- 4. Partitionstabelle auf die neue/ersetzte Platte spiegeln ---"
echo "Wenn eine neue leere HDD eingebaut wird, muss die Partitionstabelle der gesunden HDD (/dev/sdd) kopiert werden."
echo "Befehl: sfdisk -d /dev/sdd | sfdisk /dev/sdb"
# sfdisk -d /dev/sdd | sfdisk /dev/sdb  # (Auskommentiert zur Sicherheit bei Trockenübungen)
echo "INFO: In diesem Testlauf wird dieser Schritt übersprungen, da /dev/sdb physisch unverändert ist."

# 5. Neue Festplatte hinzufügen (Rebuild)
echo -e "\n--- 5. Neue/Ersetzte Festplatte wieder dem RAID hinzufügen ---"
echo "Befehl: mdadm --manage /dev/md0 --add /dev/sdb"
mdadm --manage /dev/md0 --add /dev/sdb
sleep 1

# 6. Rebuild überwachen
echo -e "\n--- 6. Rebuild-Überwachung ---"
echo "Der Rebuild-Vorgang startet jetzt im Hintergrund."
echo "Du kannst den Status überwachen mit: 'watch -n 1 cat /proc/mdstat'"
echo ""
echo "Aktueller Status:"
cat /proc/mdstat
echo ""
echo "=== FAILOVER-TEST LEITFADEN BEENDET ==="
