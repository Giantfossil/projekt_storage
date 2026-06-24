# systemd-Units & Mount-Optimierungen

Dieses Handout befasst sich mit der Modernisierung von System-Mounts und Service-Automatisierungen über systemd. Es vergleicht die klassische `/etc/fstab` mit systemd-Mount-Units und zeigt, wie man wiederkehrende Aufgaben (wie unser Speicher-Wartungsskript) über systemd-Timer steuert.

---

## 1. fstab vs. systemd Mount-Units
Unter modernen Linux-Systemen (mit systemd) generiert der `systemd-fstab-generator` beim Systemstart im Hintergrund automatisch temporäre systemd-Mount-Units aus der `/etc/fstab`. Man kann diese jedoch auch direkt als native `.mount`-Dateien in `/etc/systemd/system/` anlegen.

### Vor- und Nachteile im Vergleich:

| Kriterium | `/etc/fstab` | systemd Mount-Units |
| :--- | :--- | :--- |
| **Abhängigkeiten** | Kaum steuerbar (nur über Optionen wie `nofail` oder `x-systemd.requires`). | Vollwertiges Dependency-Handling (`After=`, `Requires=`, `Wants=`). |
| **Bedarfssteuerung** | Nur statisches Einhängen beim Systemstart. | Dynamisches Einhängen bei erstem Zugriff über `.automount`. |
| **Fehlerbehandlung** | Ein Syntaxfehler kann den Systemstart blockieren. | Fehlerhafte Units beeinträchtigen nicht den Start anderer Dienste. |
| **Modularität** | Eine große, zentrale Datei. | Einzelne, modular aktivierbare Konfigurationsdateien. |
| **Namenskonvention** | Beliebig. | **Strikt:** Dateiname muss dem Pfad entsprechen (z. B. `var-cache-build.mount` für `/var/cache/build`). |

---

## 2. systemd-Automount (.automount)
Eine `.automount`-Unit sorgt dafür, dass ein Gerät erst in dem Moment eingehängt wird, in dem ein Prozess (oder der Benutzer) auf das entsprechende Verzeichnis zugreift. 

**Vorteile für unsere Architektur:**
1. **Schnellerer Bootvorgang:** Dateisystem-Checks und Einhängevorgänge verzögern nicht den Systemstart.
2. **Umgang mit Wechselmedien (z. B. `/mnt/Backup`):** Wird das externe Backup-Laufwerk abgezogen, hängt systemd es nach einem Timeout automatisch aus. Schließt man es an und greift darauf zu, wird es sofort eingehängt.
3. **Robustheit bei Netzwerk- oder langsamen Platten:** Kein Blockieren, falls ein Datenträger beim Booten noch nicht voll initialisiert ist.

---

## 3. Automatisierung von Wartungsarbeiten: Service & Timer
Anstatt Cronjobs zu verwenden, sind systemd-Timer unter modernen Linux-Distributionen (speziell Arch Linux) der Standard für geplante Aufgaben (z. B. `fstrim.timer`).

**Vorteile von systemd-Timern:**
* **Zentrales Journaling:** Alle Logs des Skripts landen automatisch im systemd-Journal (`journalctl -u storage-maintenance`).
* **Abhängigkeiten:** Der Timer startet das Skript erst, wenn andere erforderliche Dienste (z. B. die gemounteten Platten) aktiv sind.
* **Ungenaue Timer (Accuracy):** Verhindert, dass das System durch gleichzeitiges Starten mehrerer Cronjobs überlastet wird.
* **Persistent-Flag:** Wurde das System zum geplanten Zeitpunkt ausgeschaltet, holt systemd den Lauf nach dem Einschalten automatisch nach.

---

## 4. Konfigurationsbeispiele (in `/src/Systemd/` hinterlegt)

Die zugehörigen Unit-Dateien haben wir im Verzeichnis [Systemd/](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/) abgelegt:

1. **[storage-maintenance.service](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/storage-maintenance.service)**: Definiert die Ausführung unseres Wartungsskripts `/src/Wartung_Storage.sh`.
2. **[storage-maintenance.timer](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/storage-maintenance.timer)**: Plant den Service monatlich (jeden 1. des Monats um 02:00 Uhr nachts).
3. **[var-cache-build.mount](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/var-cache-build.mount)**: Beispielhafte native Mount-Unit für die Build-Cache-SSD-Partition.
4. **[var-cache-build.automount](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/var-cache-build.automount)**: Aktiviert das Einhängen bei Dateizugriff.
5. **[mnt-Backup.automount](file:///home/giant/srv/Projekte/projekt_storage/src/Systemd/mnt-Backup.automount)**: Automount-Unit für die externe Backup-Festplatte.

---

## 5. Installation und Aktivierung von Units
Um eine eigene Unit-Datei zu aktivieren:
1. Kopiere die Dateien nach `/etc/systemd/system/`:
   ```bash
   sudo cp /src/Systemd/* /etc/systemd/system/
   ```
2. Lade den systemd-Manager neu:
   ```bash
   sudo systemctl daemon-reload
   ```
3. Aktiviere und starte den Timer (oder Mounts/Automounts):
   ```bash
   sudo systemctl enable --now storage-maintenance.timer
   sudo systemctl enable --now var-cache-build.automount
   sudo systemctl enable --now mnt-Backup.automount
   ```
4. Status prüfen:
   ```bash
   systemctl list-timers --all
   systemctl status storage-maintenance.timer
   ```
