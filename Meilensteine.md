# Projekt-Meilensteine & Roadmap

Dieses Dokument dient der strukturierten Schritt-für-Schritt-Abarbeitung aller noch offenen Aufgaben für das Storage-Projekt. Sobald eine Aufgabe abgeschlossen ist, wird sie hier abgehakt.

## Phase 1: Hardware-Vorbereitung & Storage-Basis
*Diese Phase stellt sicher, dass die physischen Laufwerke optimal konfiguriert und das Dateisystem-Layout vollständig ist.*

- [ ] **Firmware-Check-Skript:** Ein Skript unter `./src/` anlegen, das die Datenträger auf Firmware-Updates prüft.
- [x] **NVMe0 Setup:** OS-Partitionierung und Btrfs-Subvolumes auf der NVMe gemäß SOLL-Architektur abschließen.
- [x] **RAID1 & Bcache Setup:** RAID1 aus den HDDs (`/dev/sdb` & `/dev/sdd`) erstellen und die SATA-SSD (`/dev/sda`) als Caching-Device (`bcache`) vorschalten. Dabei auch die Kernel I/O-Einstellungen unter `/sys/block/...` konfigurieren.
- [ ] **fstrim:** SSD-Trim-Funktion (z.B. via `systemd`-Timer) einrichten und konfigurieren, um die Performance der SSDs langfristig sicherzustellen.

## Phase 2: Datensicherheit & Automatisierung
*Sobald das Dateisystem steht, kümmern wir uns um Backups und Snapshots.*

- [ ] **Snapper Setup:** Automatisierte Btrfs-Snapshots (CoW) konfigurieren, insbesondere für Root (`@`) und Home (`@home`), samt Auslagerung alter Snapshots.
- [ ] **Backup-Skript (rsync):** Ein Backup-Skript unter `./src/` vorbereiten, um wichtige Bestände regelmäßig auf das externe Backup-Target zu synchronisieren.

## Phase 3: Repository & Versionierung
*Sicherung der Dokumentation und der Skripte über Git.*

- [ ] **Git Setup:** Lokale Git-Basis konfigurieren (Benutzerdatenbank, GnuPG-Schlüsselhärtung).
- [ ] **Repo Init & Remote Sync:** Repository initialisieren, erste Commits setzen und dauerhaft mit einem Remote-Server synchronisieren.

## Phase 4: Betrieb, Benchmarks & Auswertung
*Validierung der in der Architektur definierten Ziele und laufende Wartung.*

- [ ] **Erste Messungen (Baseline):** Startwerte der Performance aufnehmen (z.B. durch die erstellte Build-Zeitmessung).
- [ ] **Monitoring & Delta-Werte:** Überwachung im laufenden Betrieb.
- [ ] **Auswertung:** Überprüfung der Kosten-Nutzen-Rechnung (Effektivität der Auslagerung schreibintensiver Prozesse).
- [ ] **Storage Administration:** Skripte und Dokumentation für Btrfs Scrub, Balance sowie Defragmentierung anlegen.