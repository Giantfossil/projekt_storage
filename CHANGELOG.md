# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [Unreleased] - 2026-06-24

### Hinzugefügt
- **Skripte zur Hardware-Vorbereitung und Storage-Basis (`/src/`):**
  - [Setup_NVMe.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Setup_NVMe.sh): Partitionierung der NVMe (`/dev/nvme0n1`), Formatierung mit Btrfs und Erstellung der Subvolumes (`@`, `@.snapshots`, `@cache`).
  - [Setup_RAID1_Bcache.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Setup_RAID1_Bcache.sh): Einrichtung des Software-RAID1 (`/dev/md0`) aus den HDDs (`/dev/sdb`, `/dev/sdd`), Einbindung von `bcache` (`/dev/sda` als Cache, `writeback`-Modus), Formatierung als Btrfs, Erstellung der Subvolumes (`@home`, `@home_snapshots`, `@docker`, `@_snapshots`), und Konfiguration von udev-Regeln (`/etc/udev/rules.d/60-io-scheduler.rules`) und sysctl-Parametern (`/etc/sysctl.d/60-io.conf`).
  - [Setup_fstrim.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Setup_fstrim.sh): Aktivierung und Start des wöchentlichen `fstrim.timer` für die SSDs.
  - [Setup_SSD.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Setup_SSD.sh): Partitionierung, optimierte XFS-Formatierung und Verzeichnisstrukturvorbereitung für die Workload-SSD (`/dev/sdc`).
  - [Setup_ccache.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Setup_ccache.sh): Konfiguration von ccache (`ccache.conf`) und Einrichtung von Benutzer-Umgebungsvariablen.
  - [backup_ssd.sh](file:///home/giant/srv/Projekte/projekt_storage/src/backup_ssd.sh): Rsync-Backup-Skript für libvirt VM-Images von der SSD auf das externe Backup-Laufwerk.
  - [Setup_libvirt.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Setup_libvirt.sh): Konfiguration von KVM/QEMU und libvirt, Berechtigungsanpassungen für das VM-Image-Verzeichnis und sdc1 udev-Regel.
  - [Setup_Docker.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Setup_Docker.sh): Docker-Installation, Berechtigungen, nodatacow-Erzwingung und btrfs Storage-Driver Konfiguration.
  - **systemd-Unit-Dateien (`/src/Systemd/`):**
    - [storage-maintenance.service](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/storage-maintenance.service): Service-Unit zur Kapselung des Wartungsskripts.
    - [storage-maintenance.timer](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/storage-maintenance.timer): Timer-Unit zur automatisierten monatlichen Ausführung des Services.
    - [var-cache-build.mount](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/var-cache-build.mount): Mount-Unit für die Build-Cache SSD-Partition.
    - [var-cache-build.automount](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/var-cache-build.automount): Automount-Unit zur bedarfsgesteuerten Einhängung des Build-Caches.
    - [mnt-Backup.automount](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/mnt-Backup.automount): Automount-Unit für das externe Backup-Laufwerk.
  - [Wartung_Storage.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Wartung_Storage.sh): Btrfs- und XFS-Wartungsskript für monatliche/bedarfsabhängige Scrubs, Balances und Defragmentierungen.
  - [Failover_Szenario_Test.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Failover_Szenario_Test.sh): Interaktiver Leitfaden und Simulationsskript für Software-RAID1-Festplattenausfälle, Partitionstabellenspiegelung und Rebuilds.

- **Geändert:**
  - Pfadanpassungen von `/home/dorian/` auf `/home/giant/` in [README.md](file:///home/giant/srv/Projekte/projekt_storage/README.md), [SOLL-Architektur.md](file:///home/giant/srv/Projekte/projekt_storage/docs/SOLL-Architektur.md) und [Storage-Einrichten.md](file:///home/giant/srv/Projekte/projekt_storage/docs/Storage-Einrichten.md), um dem Benutzerordner des aktuellen Workspaces zu entsprechen.
  - Aktualisierung der Status-Updates im Abschnitt `IST-Architektur` in [README.md](file:///home/giant/srv/Projekte/projekt_storage/README.md) für die neuen SSD-, Caching-, VM-, Docker-, udev-, Messungs-, Healthcheck-, Wartungs-, Failover- und systemd-Skripte/Dokumente.
  - Aktualisierung von [ToDo.txt](file:///home/giant/srv/Projekte/projekt_storage/ToDo.txt), um alle SSD-, VM-, Docker-, I/O-Messung-, Healthcheck-, Repository-, Wartungs- und Failover-Schritte als erledigt zu markieren.
  - Aktualisierung von [.gitignore](file:///home/giant/srv/Projekte/projekt_storage/.gitignore) zum korrekten Ignorieren von KDE-Konfigurationsdateien, Logdateien und Benchmark-Rückständen.

- **Konfigurationsdateien (`/Konfigurationsdateien/`):**
  - [btrbk.conf](file:///home/giant/srv/Projekte/projekt_storage/Konfigurationsdateien/btrbk.conf): Konfiguration für automatisierte Btrfs-Backups (btrbk).
  - [ccache.txt](file:///home/giant/srv/Projekte/projekt_storage/Konfigurationsdateien/ccache.txt): Dokumentation zur ccache-Konfiguration.
  - [smartd.conf](file:///home/giant/srv/Projekte/projekt_storage/Konfigurationsdateien/smartd.conf): Monitoring-Konfiguration für smartd.
  - [fstab](file:///home/giant/srv/Projekte/projekt_storage/Konfigurationsdateien/fstab): Vorgeschlagene Dateisystem-Tabelle.

- **Messungen & Protokolle (`/src/Messungen/`):**
  - [Build_Time_Messung.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Messungen/Build_Time_Messung.sh): Skript zur Zeitmessung und Cache-Analyse bei C-Kompilierungen.
  - [Messung.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Messungen/Messung.sh): Fio-Benchmark-Skript, überarbeitet zur sicheren filebasierten Messung auf SSD-Mounts.
  - [Healthcheck_Messung.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Messungen/Healthcheck_Messung.sh): Umfassendes Diagnose-Skript für SMART, Btrfs-Stats, RAID1-Status und Bcache.
  - [Healtcheck_Monitoring.sh](file:///home/giant/srv/Projekte/projekt_storage/src/Messungen/Healtcheck_Monitoring.sh): Entwurf eines Monitoring-Skripts für Healthchecks.
  - [I-O_Monitoring.md](file:///home/giant/srv/Projekte/projekt_storage/src/Messungen/I-O_Monitoring.md): Übersicht der genutzten System-Monitoring-Tools (iostat, iotop, vmstat, dstat).
  - [build_messung.md](file:///home/giant/srv/Projekte/projekt_storage/src/Messungen/build_messung.md): Testpläne und detaillierte fio-Testkonfigurationen für verschiedene Workloads.

- **Dokumentation (`/docs/`):**
  - [systemd_units_handout.md](file:///home/giant/srv/Projekte/projekt_storage/docs/systemd_units_handout.md): Leitfaden zu systemd-Units, Mounts/Automounts und Timern.
  - [Git_Anleitung.md](file:///home/giant/srv/Projekte/projekt_storage/docs/Git_Anleitung.md): Ausführliche Git- und Repository-Anleitung samt GPG/SSH-Commit-Signierung und Rebase-Workflow.
  - [udev_handout.md](file:///home/giant/srv/Projekte/projekt_storage/docs/udev_handout.md): Umfassendes Handout zu udev, Regelsyntax, I/O-Scheduler und Best Practices.
  - [SOLL-Architektur.md](file:///home/giant/srv/Projekte/projekt_storage/docs/SOLL-Architektur.md): Detaillierte Spezifikation des Soll-Zustands, Partitionslayouts und der I/O-Einstellungen.
  - [Storage-Einrichten.md](file:///home/giant/srv/Projekte/projekt_storage/docs/Storage-Einrichten.md): Anleitung für die Speicher-Initialisierung.
  - [Storage-Administration.md](file:///home/giant/srv/Projekte/projekt_storage/docs/Storage-Administration.md): Wartung und Pflege (Scrub, Balance, Defragmentierung).
  - [Meilensteine.md](file:///home/giant/srv/Projekte/projekt_storage/docs/Meilensteine.md): Übersicht und Roadmap der Projektphasen.
