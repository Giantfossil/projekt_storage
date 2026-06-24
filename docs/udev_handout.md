# udev-Handout & Best Practices

Dieses Handout dient als Leitfaden für das Verständnis, das Erstellen und das Testen von `udev`-Regeln unter Linux. Es legt den Fokus auf die Optimierung von Speichergeräten (I/O-Scheduler, Read-Ahead) und die Sicherstellung stabiler Zuweisungen.

---

## 1. Was ist udev?
`udev` ist der Gerätemanager für den Linux-Kernel. Er läuft im Userspace und lauscht auf Kernel-Ereignisse (Netlink-Sockets), die generiert werden, wenn Geräte hinzugefügt, entfernt oder geändert werden (z. B. durch Einstecken einer USB-Festplatte).

**Hauptaufgaben:**
* Dynamisches Erstellen und Entfernen von Geräteknoten im Verzeichnis `/dev/`.
* Zuweisung stabiler Symlinks (z. B. `/dev/disk/by-uuid/` oder `/dev/disk/by-id/`).
* Ausführen von Aktionen (z. B. Berechtigungen anpassen, I/O-Scheduler festlegen, Backup-Skripte starten), sobald ein Gerät erkannt wird.

---

## 2. Struktur einer udev-Regel
`udev`-Regeldateien befinden sich in `/etc/udev/rules.d/` (benutzerdefiniert) oder `/usr/lib/udev/rules.d/` (vom System bereitgestellt). Sie werden in lexikalischer Reihenfolge (nach Dateiname) verarbeitet.

Regeln bestehen aus einer Liste von **Schlüsseln (Keys)**, die durch Kommata getrennt sind. Man unterscheidet zwischen **Match-Schlüsseln** (Bedingungen) und **Assign-Schlüsseln** (Aktionen).

### Häufige Match-Schlüssel (Bedingungen)
| Schlüssel | Beschreibung | Beispiel |
| :--- | :--- | :--- |
| `ACTION` | Die Aktion des Ereignisses | `ACTION=="add"`, `ACTION=="change"` |
| `KERNEL` | Der Kernel-Name des Geräts | `KERNEL=="sd*"` |
| `SUBSYSTEM` | Das Subsystem des Geräts | `SUBSYSTEM=="block"` |
| `ATTR{...}` | Attribute des Geräts (aus `/sys/`) | `ATTR{queue/rotational}=="0"` (SSD) |
| `ENV{...}` | Umgebungsvariablen von udev | `ENV{ID_SERIAL}=="Samsung_SSD_850_PRO_*"` |

### Häufige Assign-Schlüssel (Aktionen)
| Operator | Beschreibung | Beispiel |
| :--- | :--- | :--- |
| `=` | Weist einen Wert zu (überschreibbar) | `ATTR{queue/scheduler}="mq-deadline"` |
| `+=` | Fügt einen Wert zu einer Liste hinzu | `ENV{TAGS}+="systemd"` |
| `:=` | Weist einen Wert endgültig zu | `OWNER:="root"` (verhindert spätere Änderung) |

---

## 3. Best Practice: Kernel-Name vs. ID_SERIAL
Gerätebezeichnungen im Kernel (wie `/dev/sda`, `/dev/sdb`, `/dev/sdc`) sind **nicht persistent** und können sich nach jedem Systemstart ändern. 

> [!WARNING]
> Verwende für gerätespezifische Regeln niemals den Kernel-Namen (`KERNEL=="sdc"`), wenn die Regel nur für ein ganz bestimmtes physisches Laufwerk gelten soll. Nutze stattdessen die eindeutige Seriennummer (`ENV{ID_SERIAL}`).

### Ermittlung der eindeutigen ID_SERIAL:
```bash
udevadm info --query=all --name=/dev/sdc | grep ID_SERIAL
```
*Ausgabebeispiel:*
```text
E: ID_SERIAL=Samsung_SSD_850_PRO_S2RZNX0H123456Y
E: ID_SERIAL_SHORT=S2RZNX0H123456Y
```

**Spezifische Regel mit Seriennummer:**
```udev
ACTION=="add|change", SUBSYSTEM=="block", ENV{ID_SERIAL}=="Samsung_SSD_850_PRO_*", ATTR{queue/scheduler}="mq-deadline"
```

---

## 4. Wichtige I/O-Attribute für Speichergeräte
Im Verzeichnis `/sys/block/<gerät>/queue/` stellt der Kernel verschiedene Attribute zur Performance-Steuerung bereit, die per `udev` konfiguriert werden können:

1. **`queue/rotational`**
   * `0`: Das Laufwerk ist nicht-rotierend (SSD, NVMe).
   * `1`: Das Laufwerk ist rotierend (HDD).
   * *Nutzung:* Perfekt, um pauschale Optimierungen für alle SSDs oder HDDs anzuwenden.

2. **`queue/scheduler`**
   * Legt den I/O-Scheduler fest.
   * *Optionen:* `none` (NVMe), `mq-deadline` (SATA-SSD mit NCQ), `bfq` (HDD / gemischte Last).

3. **`queue/read_ahead_kb`**
   * Bestimmt, wie viele Kilobyte der Kernel bei sequentiellen Zugriffen vorausschauend in den RAM liest.
   * *Optimierung:* Höhere Werte (z. B. `2048` oder `4096`) helfen HDDs und RAIDs bei großen Dateien. Niedrigere Werte (z. B. `128` oder `256`) sind ideal für SSDs mit zufälligen Zugriffsmustern.

4. **`queue/nr_requests`**
   * Maximale Anzahl der in der Queue wartenden Lese-/Schreibanfragen.
   * *Optimierung:* Erhöhung auf `64` oder `128` bei schnellen SSDs unter hoher Last.

---

## 5. Die udev-Regeln in unserem Projekt
Unsere Projektkonfiguration in `/etc/udev/rules.d/60-io-scheduler.rules` vereint diese Optimierungen:

```udev
# 1. SATA-SSDs (sdc) — mq-deadline und reduzierter Read-Ahead zur Verringerung von Overhead
ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="0", \
  ATTR{queue/scheduler}="mq-deadline", \
  ATTR{queue/nr_requests}="32", \
  ATTR{queue/read_ahead_kb}="256"

# 2. HDDs (sdb, sdd — md0 Member) — bfq für faire Lastverteilung bei parallelen Zugriffen
ACTION=="add|change", KERNEL=="sd[bd]", ATTR{queue/rotational}=="1", \
  ATTR{queue/scheduler}="bfq", \
  ATTR{queue/read_ahead_kb}="2048"

# 3. RAID1-Verbund (md0) — Erhöhter Read-Ahead auf Software-RAID-Ebene
ACTION=="add|change", KERNEL=="md0", ATTR{queue/read_ahead_kb}="4096"

# 4. VM-Partition (sdc1 — libvirt) — Partition-Level Read-Ahead-Erhöhung für qcow2-VM-Images
ACTION=="add|change", KERNEL=="sdc1", RUN+="/usr/bin/blockdev --setra 2048 %N"
```

---

## 6. Testen und Anwenden von Regeln
Wenn Regeln bearbeitet wurden, müssen sie neu geladen und auf bereits angeschlossene Geräte angewendet werden.

### Regeln neu laden:
```bash
sudo udevadm control --reload-rules
```

### Regeln auf existierende Geräte anwenden:
```bash
sudo udevadm trigger --type=devices --action=change
```

### Trockenübung (Simulieren eines Events zur Fehlersuche):
Um zu prüfen, welche Regeln auf ein bestimmtes Gerät zutreffen und welche Attribute gesetzt werden, ohne das System tatsächlich zu ändern:
```bash
udevadm test --action=change /sys/block/sdc/sdc1
```
*(Die Ausgabe zeigt Schritt für Schritt, welche Regeldateien gelesen werden und welche Aktionen udev ausführen würde).*
