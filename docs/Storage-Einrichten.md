# Storage-Einrichtung & Implementierung

> **WICHTIGER HINWEIS (Secure Erase):** 
Bevor man mit der Formatierung und Partitionierung beginnst, wird dringend empfohlen, alle SSDs (inkl. NVMe) einem Secure Erase zu unterziehen (z.B. mittels `nvme format` oder `hdparm`). Dadurch werden die Flash-Zellen in ihren Ursprungszustand zurückversetzt, alte Controller-Mappings gelöscht und die maximale Performance für die Benchmarks sichergestellt.

**Beispiel für eine NVMe-SSD:**
```bash
# Zeigt verfügbare LBA-Formate und unterstützte Features an
sudo nvme id-ns -H /dev/nvme0n1

# Führt den Secure Erase durch (Achtung: Unwiderruflicher Datenverlust!)
sudo nvme format /dev/nvme0n1 --ses=1
```

> **HINWEIS (Firmware):**
Es lohnt sich generell ein Firmware Update seiner Datentraeger Hardware zu machen.
In meinen Fall:
  * `OpenSeaChest` (Seagate)
    - NCQ-Einstellungen anpassen (z.B. Queue Depth, Command Queuing)
    - Firmware-spezifische Optimierung
    - SMART-Daten auslesen und anpassen
  * `samsung-ssd-fwupdate` (Samsung)
  * samsung-ssd-dc-toolkit
  * samsung_magician-consumer-ssd
  * samloader-git
  
  
  | Festplatte | NCQ-Unterstützung | OpenSeaChest-Unterstützung | Mögliche Vorteile |
  | --- | --- | --- | --- |
  | ST1000LM024 HN-M101MBB | Ja | Ja | NCQ-Optimierung, Queue Depth anpassen, SMART-Daten detailliert auslesen |
  | ST2000DM001-1CH164 | Ja | Ja | NCQ-Optimierung, Queue Depth anpassen, Firmware-spezifische Einstellungen |

Diese Dokumentation beinhaltet alle notwendigen Befehle, um die in der SOLL-Architektur definierten Datenträgerstrukturen umzusetzen.

## 1. Partitionierung & Formatierung (Workload-SSD /dev/sdc)

**Alte Datenstrukturen löschen und neue Partitionen anlegen:**

```bash
sudo sgdisk --zap-all /dev/sdc
sudo sgdisk -n 1:0:+200G  -t 1:8300 -c 1:"libvirt"  /dev/sdc
sudo sgdisk -n 2:0:+30G   -t 2:8300 -c 2:"logs"     /dev/sdc
sudo sgdisk -n 3:0:+120G  -t 3:8300 -c 3:"build"    /dev/sdc
sudo sgdisk -n 4:0:+50G   -t 4:8300 -c 4:"ccache"   /dev/sdc
```
*Hinweis: Es wird 100G frei gelassen.*

**Formatierung mit XFS:**

```bash
sudo mkfs.xfs -L libvirt  -f /dev/sdc1
sudo mkfs.xfs -L logs     -f /dev/sdc2
sudo mkfs.xfs -L build    -f /dev/sdc3
sudo mkfs.xfs -L ccache   -f /dev/sdc4
```

---

## 2. RAID1 erstellen (HDDs /dev/sdb & /dev/sdd)

```bash
sudo wipefs -f /dev/sd[d,b]
```
*Hinweis: Datentraeger von möglichen Altlast befreien*

```bash
sudo mdadm --create /dev/md0 \
  --level=1 \
  --raid-devices=2 \
  --chunk=512 \
  /dev/sdb /dev/sdd
```
*Hinweis: `--chunk=512` ist optimiert für 4K-Physical-Sektor-Drives.*

---

## 3. Systemkonfigurationen anwenden

**udev-Regeln für I/O-Scheduler aktivieren:**

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger --type=devices --action=change
```

**sysctl-Parameter (Dirty-Pages & Writeback) ohne Neustart laden:**

```bash
sudo sysctl --system
```

---

## 4. Userspace-Caches & Bindmounts vorbereiten

Damit die Bindmounts aus der `fstab` fehlerfrei funktionieren, müssen die Ziel- und Quellverzeichnisse vorab erstellt und mit den richtigen Berechtigungen versehen werden. (Hier beispielhaft für den Nutzer `dorian`).

```bash
# Mountpoints im Home-Verzeichnis anlegen
mkdir -p /home/dorian/.cache/build
mkdir -p /home/dorian/.cache/ccache
chown dorian:dorian /home/dorian/.cache/build
chown dorian:dorian /home/dorian/.cache/ccache

# Berechtigungen auf SSD-Seite sicherstellen
sudo chmod 1777 /tmp
sudo chmod 1777 /var/tmp
sudo mkdir -p /var/cache/build /var/cache/ccache
sudo chown dorian:dorian /var/cache/build
sudo chown dorian:dorian /var/cache/ccache
```
