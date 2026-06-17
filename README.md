# Projekt /// Storage
=====================================

> Kurzbeschreibung: Das Projekt befasst sich mit der Einrichtung eines Storagesystems und einer Analyse inkl. Auswertung.
> Abgrenzung: Der Fokus dieses Projektes bezieht sich auf eine lokale Linux-Umgebung. Technisch grenzt sich das Projekt in der Ausstattung von einer professionellen Umgebung ab (Datenträger etc.). Die verfolgten Ziele dienen einer privaten, produktiven Umgebung mit Lastverteilung und priorisierten Prozessen.

## Vorwort

### Zu meiner Person

Name: Dorian
Berufliche Situation:

* Auszubildender (Fachinformatiker für Systemintegration)
* Schwerpunkt:
  * Linux Desktop/Server
  * Storage-Systeme (Hardware, Benchmark, Architektur und Datenrettung)
  * Datenmigration
  * Containerisierung
* Zusätzliche Kenntnisse:
  * Vertieftes Wissen in OpenSSH, GnuPG

### Meine Intention

Ich möchte anhand dieses Repositories mir ein Homelab einrichten. Die Umgebung soll mich darin unterstützen, mein Interesse in den Bereichen Storage, Virtualisierung/Containerisierung und Datenmigration zu fördern. Die Effektivität und Integrität dieses Setups werde ich anhand von Messprotokollen (Startwert) und den fortlaufenden Monitorings (Deltawerte) der Umgebung bewerten.
Bewertet wird, wie bereits einmal erwähnt:
* Integrität (Datenträger)
* Datendurchsatz Engpässe (Zukünftige Weiterentwicklung)
* Eine Art Kosten-Nutzen-Rechnung (Messung eines Buildvorgangs und des dafür extra bereitgestellten Datenträgers) meiner Priorisierung der Buildprozesse (anhand eines Beispiels in der Kompilierung von `C`-Code)

## IST-Architektur

* [IST-Analyse (Hardware)](/src/IST-Analyse.sh)
* [SYS-Analyse (System & Storage)](/src/SYS-Analyse.sh)
* [Storage Info](/src/gather_storage_info.sh)
* [Build-Zeitmessung](/src/Messungen/Build_Time_Messung.sh)
* [IST-Architektur (Dokumentation)](/docs/IST-Architektur.md)
* **Status-Update:** Skript für RAID1 & Bcache-Setup (`/src/Setup_RAID1_Bcache.sh`) erstellt.
* **Status-Update:** Skript für NVMe-Setup (`/src/Setup_NVMe.sh`) erstellt.

## SOLL-Architektur


* [Konzeptskizze](/docs/Konzeptskizze.pdf)


* [SOLL-Architektur](/docs/SOLL-Architektur.md)

## Initalisierung

* [Storage-Einrichten](/docs/Storage-Einrichten.md)


## Konfiguration

### `/etc/fstab`
```fstab
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
/var/cache/build   /home/dorian/.cache/build   none  defaults,bind,nofail,x-systemd.requires=/var/cache/build   0 0
/var/cache/ccache  /home/dorian/.cache/ccache  none  defaults,bind,nofail,x-systemd.requires=/var/cache/ccache  0 0

# tmpfs
tmpfs     /tmp  tmpfs  defaults,noatime,nosuid,nodev,size=3G,mode=1777  0 0
```

### `/etc/udev/rules.d/60-io-scheduler.rules`
```udev
# SATA SSD (sdc) — mq-deadline
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline", ATTR{queue/nr_requests}="32", ATTR{queue/read_ahead_kb}="256"
# HDD (sdb, sdd — md0 Member) — bfq
ACTION=="add|change", KERNEL=="sd[bd]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq", ATTR{queue/read_ahead_kb}="2048"
# RAID1 (md0) — Read-Ahead Erhöhung auf md-Ebene
ACTION=="add|change", KERNEL=="md0", ATTR{queue/read_ahead_kb}="4096"
```

### `/etc/sysctl.d/60-io.conf`
```ini
vm.dirty_ratio = 10
vm.dirty_background_ratio = 3
vm.dirty_expire_centisecs = 3000
vm.dirty_writeback_centisecs = 1500
vm.swappiness = 10
vm.vfs_cache_pressure = 100
dev.raid.speed_limit_min = 50000
dev.raid.speed_limit_max = 200000
```

## Administration

* [Storage-Administration](/docs/Storage-Administration.md)
  * Btrfs Wartung (Scrub & Balance)
  * Fragmentierung & Defragmentierung

## Messungen


## Weiterentwicklung


## Fazit
Zukünftiges Arbeiten mit einer K.I. werden ich mit einen Planungsphase des Projekts starten. Um erstmal klare Etappen und Meilensteine zu definieren. Die man dann Schritt für Schritt ab arbeiten kann. Das wird sich besonders in der Struktur und in der wiedereinarbeitung im Projekt positiv bemerkbar machen.
Außer dem eine a.i.-instruktion so erweitern dass ständig auch alles auf eine sauberer formulierung kontrolliert wird.