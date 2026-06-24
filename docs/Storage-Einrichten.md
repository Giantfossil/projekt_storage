# Storage-Einrichtung & Implementierung

> **WICHTIGER HINWEIS (Secure Erase):** 
Bevor man mit der Formatierung und Partitionierung beginnt, wird dringend empfohlen, alle SSDs (inkl. NVMe) einem Secure Erase zu unterziehen (z.B. mittels `nvme format` oder `hdparm`). Dadurch werden die Flash-Zellen in ihren Ursprungszustand zurückversetzt, alte Controller-Mappings gelöscht und die maximale Performance für die Benchmarks sichergestellt.

**Beispiel für eine NVMe-SSD:**
```bash
# Zeigt verfügbare LBA-Formate und unterstützte Features an
sudo nvme id-ns -H /dev/nvme0n1

# Führt den Secure Erase durch (Achtung: Unwiderruflicher Datenverlust!)
sudo nvme format /dev/nvme0n1 --ses=1
```

> **HINWEIS (Firmware):**
Es besteht die Möglichkeit, ein Firmware-Update seiner Datenträger-Hardware durchzuführen.
In meinem Fall:
  * `OpenSeaChest` (Seagate)
    - NCQ-Einstellungen anpassen (z.B. Queue Depth, Command Queuing)
    - Firmware-spezifische Optimierung
    - SMART-Daten auslesen und anpassen
  * `samsung-ssd-fwupdate` / `Samsung Magician` (Samsung)
  * `crucial-storage-executive` (Crucial)
  * `smartmontools` / `hdparm` (Toshiba & Allgemein)
  
  
  | Datenträger | Modell | Typ / Protokoll | Tool-Unterstützung | Mögliche Vorteile |
  | --- | --- | --- | --- | --- |
  | `/dev/sdb` | ST1000LM024 HN-M101MBB (Seagate) | HDD / SATA | `OpenSeaChest` | NCQ-Optimierung, Queue Depth anpassen, detailliertes SMART |
  | `/dev/sde` | ST2000DM001-1CH164 (Seagate) | HDD / SATA | `OpenSeaChest` | NCQ-Optimierung, Queue Depth anpassen, Firmware-Einstellungen |
  | `/dev/sda` | Samsung SSD 850 EVO 250GB | SSD / SATA | `samsung-ssd-fwupdate`, `Magician` | Firmware-Update, Over-Provisioning, Gesundheitsstatus prüfen |
  | `/dev/sdc` | Samsung SSD 850 PRO 512GB | SSD / SATA | `samsung-ssd-fwupdate`, `Magician` | Firmware-Update, Over-Provisioning, Gesundheitsstatus prüfen |
  | `/dev/nvme0n1`| Crucial CT500P5SSD8 | SSD / NVMe | `crucial-storage-executive` | Firmware-Update, Namespace-Verwaltung, Secure Erase, SMART |
  | `/dev/sdd` | TOSHIBA MQ01ABD100 | HDD / SATA | `smartmontools`, `hdparm` | Allgemeine SMART-Überwachung, APM/AAM-Anpassungen |

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

Damit die Bindmounts aus der `fstab` fehlerfrei funktionieren, müssen die Ziel- und Quellverzeichnisse vorab erstellt und mit den richtigen Berechtigungen versehen werden. (Hier für den Nutzer `giant`).

```bash
# Mountpoints im Home-Verzeichnis anlegen
mkdir -p /home/giant/.cache/build
mkdir -p /home/giant/.cache/ccache
chown giant:giant /home/giant/.cache/build
chown giant:giant /home/giant/.cache/ccache

# Berechtigungen auf SSD-Seite sicherstellen
sudo chmod 1777 /tmp
sudo chmod 1777 /var/tmp
sudo mkdir -p /var/cache/build /var/cache/ccache
sudo chown giant:giant /var/cache/build
sudo chown giant:giant /var/cache/ccache
```
