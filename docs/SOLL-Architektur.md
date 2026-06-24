# SOLL-Architektur

## Designziele:

> Ziele des Tier-Leveling, Priorisierung und des einfachen Handlings

**NVMe:**
- Kapazität entlasten durch Auslagerung von Cold-Daten (`@home` und ältere Snapshots) (inkl. automatisch schlankerer Snapshots-Schreibprozesse)
- Auslagerung systemunrelevanter schreibintensiver Prozesse (`/var/log`) und primär für Latenz fordernde Zugriffe verwenden
- Formatierung in einem für SSDs geeigneten Dateisystem (`BtrFS`), das zusätzlich mit einer Snapshot-Funktion ausgestattet ist.
**RAID1:**
- Formatierung in `BtrFS` für die schnellere Übertragung älterer Snapshots
- Redundante Speicherung von Cold-Daten auf den HDDs
- Zentralisierung und Vereinfachung der Konsolidierung relevanter Daten (Benutzereinstellungen/-anpassungen, Dokumentationsunterlagen und fertigen Container-Images)
- Caching von 200GB der meist genutzten Daten anhand eines SSD-bcaches
**SSD:**
- Priorisierung von Prozessen (Compiler-Cache, Build-Artefakte, VM-Images) auf einem dedizierten SSD-Datenträger
- Outsourcing und Isolierung von zufälligen, schreibintensiven I/O-Prozessen (`ccache`, `build`, `libvirt`), für eine gleichmäßigere Lastverteilung
- Formatierung in einem für die Aufgaben geeigneteren Dateisystem (`xfs`), in dem auch die Snapshot-Funktion bzw. CoW nicht zwangsläufig wichtig ist (Backup via `rsync` der Partition: /dev/sdc1 erfüllt die Anforderungen)

## Geräteübersicht

| Gerät          | Modell                | Typ               | Schnittstelle | Sektorgröße log./phys.      | Verwendung                       |
| -------------- | --------------------- | ----------------- | ------------- | --------------------------- | -------------------------------- |
| `/dev/nvme0n1` | Crucial CT500P5SSD8   | NVMe MLC          | PCIe          | 512B / 512B                 | Betriebssystem                   |
| `/dev/sdc`     | Samsung 850 PRO 512GB | SATA SSD MLC      | SATA 6 Gb/s   | 512B / 512B                 | Workload-Caches                  |
| `/dev/sdb`     | Seagate ST1000LM024   | HDD               | SATA          | 512B log. / 4K phys. (512e) | md0 Member                       |
| `/dev/sdd`     | Toshiba MQ01ABD100    | HDD               | SATA          | 512B log. / 4K phys. (512e) | md0 Member                       |
| `/dev/md0`     | —                     | RAID1 Software    | md            | —                           | Home, Docker, Snapshots          |
| `/dev/sda`     | Samsung 850 EVO 250GB | SATA SSD          | SATA 6 Gb/s   | 512B / 512B                 | bcache (Caching-Device für md0)  |
| `/dev/sdf1`    | —                     | —                 | —             | —                           | Backup-Target (2TB, /mnt/Backup) |
| `tmpfs`        | —                     | RAM               | —             | —                           | /tmp                             |
| `zram`         | —                     | RAM (komprimiert) | —             | —                           | Swap-Ersatz                      |

---

## Partitionslayout

### `/dev/nvme0n1` — Betriebssystem (btrfs)

| Partition        | Mountpoint    | Größe      | Dateisystem  | Subvolume     |
| ---------------- | ------------- | ---------- | ------------ | ------------- |
| `/dev/nvme0n1p1` | `/efi`        | 2 GiB      | vfat (FAT32) | —             |
| `/dev/nvme0n1p3` | `/`           | 463,76 GiB | btrfs        | `@`           |
| `/dev/nvme0n1p3` | `/.snapshots` | (shared)   | btrfs        | `@.snapshots` |
| `/dev/nvme0n1p3` | `/var/cache`  | (shared)   | btrfs        | `@cache`      |

`/var/cache` liegt als eigenes Subvolume auf der NVMe, damit Snapper-Snapshots von `/` keine Cache-Daten einschließen. Die eigentlichen Workload-Caches werden per Bindmount von `/dev/sdc` überschrieben.

---

### `/dev/sdc` — Workload-SSD (XFS, GPT)

| Partition   | Mountpoint          | Größe    | Dateisystem | Workload                        |
| ----------- | ------------------- | -------- | ----------- | ------------------------------- |
| `/dev/sdc1` | `/var/lib/libvirt`  | 200 GiB  | XFS         | VM-Images, qcow2, ISOs          |
| `/dev/sdc2` | `/var/log`          | 30 GiB   | XFS         | journald, syslog, App-Logs      |
| `/dev/sdc3` | `/var/cache/build`  | 120 GiB  | XFS         | cargo, pip, makepkg SRCDEST     |
| `/dev/sdc4` | `/var/cache/ccache` | 50 GiB   | XFS         | ccache (C/C++-Compiler-Cache)   |
| (Reserve)   | —                   | ~100 GiB | —           | Puffer gegen XFS-Fragmentierung |

> **Hinweis:** XFS fragmentiert spürbar bei >90 % Belegung. Die Reserve ist bewusst eingeplant.

---

### `/dev/md0` — RAID1 (btrfs, 2×1TB HDD)

| Subvolume         | Mountpoint         | Verwendung                     |
| ----------------- | ------------------ | ------------------------------ |
| `@home`           | `/home`            | Benutzerdaten (bcache0-backed) |
| `@home_snapshots` | `/home/.snapshots` | Snapper-Snapshots von /home    |
| `@docker`         | `/var/lib/docker`  | Docker-Daten (nodatacow)       |
| `@_snapshots`     | `/home/snapshots`  | Auslagerung alter Snapshots von der NVMe |


> `--chunk=512` (512 KiB) ist optimal für 4K-Physical-Sektor-Drives (512e).

---

## I/O-Einstellungen

### `/dev/sdc` — SATA SSD

| Parameter              | Wert          | Begründung                                                                               |
| ---------------------- | ------------- | ---------------------------------------------------------------------------------------- |
| `scheduler`            | `mq-deadline` | SATA-SSD mit NCQ; `none` nur für NVMe mit nativer Warteschlange                          |
| `nr_requests`          | `32`          | Entspricht NCQ-Tiefe des 850 PRO                                                         |
| `read_ahead_kb`        | `256`         | Reduziert gegenüber Default; Random-Workloads profitieren nicht von aggressivem Prefetch |
| `read_ahead_kb` (sdc1) | `1024`        | qcow2-Reads sind überwiegend sequentiell                                                 |
| `rq_affinity`          | `2`           | Completion auf dem CPU ausführen, der den Request abgeschickt hat                        |

### `/dev/sdb`, `/dev/sdd` — HDD (md0 Member)

| Parameter       | Wert   | Begründung                                                                                                    |
| --------------- | ------ | ------------------------------------------------------------------------------------------------------------- |
| `scheduler`     | `bfq`  | Budget Fair Queueing; faire Lastverteilung bei gemischter I/O, besser als `mq-deadline` für rotierende Medien |
| `read_ahead_kb` | `2048` | Sequentielle Prefetch-Optimierung für HDD                                                                     |

### `/dev/md0` — RAID1

| Parameter        | Wert          | Begründung                                                       |
| ---------------- | ------------- | ---------------------------------------------------------------- |
| `read_ahead_kb`  | `4096`        | RAID1-Prefetch auf md-Ebene (erbt nicht automatisch von Members) |
| `sync_speed_min` | `50000 kB/s`  | Mindest-Resync-Geschwindigkeit                                   |
| `sync_speed_max` | `200000 kB/s` | Rebuild blockiert nicht den normalen I/O                         |

---

## fstab

```
# /etc/fstab

# NVMe — btrfs Subvolumes
LABEL=nvme_root  /            btrfs  subvol=/@,rw,noatime,compress=zstd:3,commit=30,space_cache=v2 0 0
LABEL=nvme_root  /.snapshots  btrfs  subvol=@.snapshots,noatime,x-gvfs-show 0 0
LABEL=nvme_root  /var/cache   btrfs  subvol=/@cache,noatime,nodatacow,nodev,nosuid,noexec,compress=zstd:1  0 0
LABEL=00CF-12A3  /efi         vfat   noatime,nodev,noexec,nosuid,dmask=0077,fmask=0177  0 2

# SSD /dev/sdc — XFS Workload-Partitionen
LABEL=libvirt    /var/lib/libvirt   xfs  defaults,noatime,nodiratime,largeio,swalloc        0 2
LABEL=logs       /var/log           xfs  defaults,noatime,nodiratime,nodev,noexec                       0 2
LABEL=build      /var/cache/build   xfs  defaults,noatime,nodiratime,nodev,nosuid                        0 2
LABEL=ccache     /var/cache/ccache  xfs  defaults,noatime,nodiratime,nodev,nosuid                        0 2

# 2x 1TB HHD /dev/md0 + 1x 250GB SSD /dev/bcache0
LABEL=md0_home   /home              btrfs  subvol=@home,defaults,rw,nodev,nosuid,noatime,compress=zstd:2  0 0
LABEL=md0_home   /home/.snapshots   btrfs  subvol=@home_snapshots,noatime,nodatacow,noexec,nodev  0 0
LABEL=md0_home   /var/lib/docker    btrfs  subvol=/@docker,subvolid=257,noatime,nodatacow,nodev,nosuid,space_cache=v2 0 0

# Bindmounts — Userspace-Caches
/var/cache/build   /home/giant/.cache/build   none  defaults,bind,nofail,x-systemd.requires=/var/cache/build   0 0
/var/cache/ccache  /home/giant/.cache/ccache  none  defaults,bind,nofail,x-systemd.requires=/var/cache/ccache  0 0

# tmpfs
tmpfs     /tmp  tmpfs  defaults,noatime,nosuid,nodev,size=3G,mode=1777  0 0
```

---

## udev-Regeln

**`/etc/udev/rules.d/60-io-scheduler.rules`**

```
# SATA SSD (sdc) — mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", \
  ATTR{queue/scheduler}="mq-deadline", \
  ATTR{queue/nr_requests}="32", \
  ATTR{queue/read_ahead_kb}="256"

# HDD (sdb, sdd — md0 Member) — bfq
ACTION=="add|change", KERNEL=="sd[bd]", ATTR{queue/rotational}=="1", \
  ATTR{queue/scheduler}="bfq", \
  ATTR{queue/read_ahead_kb}="2048"
```

---

## sysctl

**`/etc/sysctl.d/60-io.conf`**

```ini
# Dirty-Page-Verhältnis
# Reduziert gegenüber Default (20/10), da zram als Puffer vorhanden
vm.dirty_ratio = 10
vm.dirty_background_ratio = 3

# Writeback-Intervall
# 3s statt Default 5s — kürzere Burst-Fenster, weniger Datenverlustrisiko
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 1500

# Swappiness
# Niedrig, da zram als primäres Swap; kein Swap auf rotierende Medien
vm.swappiness = 10

# VFS Cache Pressure
# Standard 100; bei viel RAM ggf. auf 50 reduzieren (Inode/Dentry-Cache länger halten)
vm.vfs_cache_pressure = 100
```

---

## Bindmounts (Userspace-Caches)

Build- und Compiler-Caches laufen als Nutzer `$USER` unter `~/.cache/`. Damit diese auf der SSD liegen, ohne `~`-Pfade in `fstab` zu verwenden (nicht zulässig, da kein absoluter Pfad), werden Bindmounts von `/var/cache/` nach `/home/${USER}/.cache/` eingerichtet.

```
/var/cache/build   ──bind──▶  /home/${USER}/.cache/build
/var/cache/ccache  ──bind──▶  /home/${USER}/.cache/ccache
```

**Voraussetzung:** Verzeichnisse müssen existieren und die richtigen Berechtigungen haben:

```bash
# Mountpoints anlegen
mkdir -p /home/$USER/.cache/build
mkdir -p /home/$USER/.cache/ccache
chown $USER:$USER /home/$USER/.cache/build
chown $USER:$USER /home/$USER/.cache/ccache

# Berechtigungen auf SSD-Seite
sudo chmod 1777 /tmp
sudo chmod 1777 /var/tmp
chown $USER:$USER /var/cache/build
chown $USER:$USER /var/cache/ccache
```
**Zusätzliche wichtige XDG-Komforme-Variablen**

```bash
mkdir -p /home/$USER/.config
mkdir -p /home/$USER/.local/share
mkdir -p /home/$USER/.local/state
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
```

**Umgebungsvariablen in `~/.bash_profile`:**

```bash
export CCACHE_DIR="$HOME/.cache/ccache"
export CARGO_HOME="$HOME/.cache/build/cargo"
export PIP_CACHE_DIR="$HOME/.cache/build/pip"
```

**Manuelle Validierung nach Reboot:**

```bash
findmnt /home/$USER/.cache/build
findmnt /home/$USER/.cache/ccache
```

---

## Begründungen

### Warum XFS auf `/dev/sdc`?

XFS ist für große Dateien und hohen sequentiellen Durchsatz optimiert — genau der Anwendungsfall für qcow2-VM-Images, Build-Artefakte und Compiler-Caches. btrfs auf der SSD würde CoW-Overhead (Copy-on-Write) für libvirt-Images erzeugen, das durch `nodatacow` umgangen werden müsste, was XFS hier direkt überlegen macht.

### Warum `/opt` nicht ausgelagert?

`/opt` enthält typischerweise statische Binaries ohne relevante Schreiblast. Eine Auslagerung bringt keinen messbaren Performance-Gewinn und erhöht die Komplexität des Mounts unnötig.

### Warum 100 GiB Reserve auf `/dev/sdc`?

XFS fragmentiert bei Belegung über 90 % spürbar, da der Allocator dann keine zusammenhängenden Extents mehr findet. Die Reserve hält die Belegung dauerhaft unter dieser Schwelle.

### Warum `mq-deadline` statt `none` auf der SATA-SSD?

`none` (kein Scheduling) eignet sich für NVMe-Drives mit nativer Command-Queue auf Controllerebene. SATA-SSDs mit NCQ profitieren von `mq-deadline`, da der Scheduler die Request-Reihenfolge für die NCQ-Warteschlange optimiert und Latenz-Fairness sicherstellt.

### Warum `bfq` auf den HDDs?

Budget Fair Queueing weist jedem Prozess ein I/O-Budget zu und verhindert so, dass ein einzelner Prozess (z. B. ein `resync` oder ein Backup-Job) die gesamte Disk-Bandbreite monopolisiert. Für gemischte Workloads auf rotierenden Medien ist `bfq` `mq-deadline` klar überlegen.

### Warum Bindmounts statt direkter `~`-Pfade in fstab?

`fstab` erwartet absolute Pfade. `~` wird vom Kernel nicht expandiert. Bindmounts erlauben es, systemseitig verwaltete Verzeichnisse unter `/var/cache/` transparent im Userspace unter `~/.cache/` bereitzustellen — ohne dass Tools wie `cargo`, `ccache` oder `pip` angepasst werden müssen.

---

_Erstellt mit io-status.sh — aktuellen Ist-Zustand jederzeit prüfbar._
