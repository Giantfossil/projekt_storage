# Storage-Administration

Dieses Dokument beschreibt die regelmäßigen Wartungsaufgaben, um die Performance, Integrität und Lebensdauer der Storage-Architektur sicherzustellen.

## Btrfs Wartung

### 1. Scrub (Integritätsprüfung)
**Wann?** Monatlich (z.B. via `systemd`-Timer).
**Warum?** Btrfs speichert Prüfsummen (Checksums) für alle Daten und Metadaten. Ein Scrub liest alle Blöcke und vergleicht sie mit ihren Checksums, um "Bit Rot" (schleichende Datenkorruption) oder defekte Festplattensektoren frühzeitig zu erkennen. Im RAID1-Verbund (`md0`) repariert Btrfs fehlerhafte Blöcke automatisch durch die redundante Kopie.

### 2. Balance (Datenverteilung)
**Wann?** Nach Bedarf (z. B. wenn sich Festplatten asymmetrisch füllen, nach dem Löschen massiver Datenmengen oder wenn neue Laufwerke ins Array aufgenommen werden).
**Warum?** Btrfs organisiert Daten in sogenannten "Chunks". Wenn Chunks nur noch teilweise belegt sind, blockieren sie dennoch den Platz. Ein Balance-Vorgang konsolidiert diese Chunks und gibt Speicherplatz frei. Es verhindert den "No space left on device"-Fehler, wenn augenscheinlich noch Platz vorhanden ist, aber keine neuen Metadaten-Chunks mehr allokiert werden können.

### 3. Defragmentierung
**Wann?** Gelegentlich für bestimmte Workloads (oder automatisch via `autodefrag` Mount-Option).
**Warum?** Die Copy-on-Write (CoW) Natur von Btrfs führt bei zufälligen Schreibzugriffen (z. B. Datenbanken, Log-Dateien, P2P-Downloads) zu massiver Fragmentierung. Dadurch müssen Festplattenköpfe viel springen und die Latenzen steigen. 
*Hinweis: Da wir für unsere schreibintensiven VM-Images XFS verwenden, ist dieses Risiko in unserer Architektur bereits stark abgemildert.*

## XFS Wartung

XFS fragmentiert ebenfalls im Laufe der Zeit, kann damit aber generell sehr gut umgehen. In unserer SOLL-Architektur beugen wir massiven Einbrüchen vor, indem wir **100 GiB auf `/dev/sdc` als Reserve** unpartitioniert lassen (XFS fragmentiert bei über 90 % Belegung spürbar).

### Defragmentierung (`xfs_fsr`)
**Wann?** Selten (alle paar Monate oder bei messbarem Performance-Einbruch).
**Warum?** Um Dateifragmente auf der XFS-Partition für Build-Caches und VMs wieder zu großen, zusammenhängenden Blöcken (Extents) zusammenzufügen und so die sequentielle Leserate hochzuhalten.