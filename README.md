# Projekt /// Storage
=====================================

> Kurzebeschreibung: Das Projekt befasst sich um die Einrichtung eines Storagesystems und einer Analyse inkl Auswertung.
> Abgrenzung:  Der Fokus dieses Projektes bezieht sich auf eine lokale Linux Umgebung. Technischen grenzt sich das Projekt in der Ausstattung zu einer professionellen Umgebung ab (Datentraeger etc.). Die verfolgte Ziele dienen einer privaten produktiven Umgebung mit Lastverteilung und priorisierten Prozessen.

## Vorwort

### Zu meiner Person

Name: Dorian
Berufliche Situation:

* Auszubildener (Fachinformatiker für Systemintegration)
* Schwerpunkt:
  * Linux Desktop/Server
  * Storage Systeme (Hardware,Benchmark, Architektur und Datenrettung)
  * Datenmigration
  * Containerisierung
* Zusätzliche Kenntnisse:
  * Vertiefstes Wissen in OpenSSH, GnuPG

### Meine Intention

Ich möchte anhand dieser Repository mir ein Homelab einrichten. Die Umgebung soll mich darin unterstützen mein Interesse in den Bereichen: Storage, Virtualisierung/Containerisierung und Datenmigration zu unterstützten. Die Effektivität und Integrität dieses Setups werde ich anhand von Messprotokollen (Startwert) und den fortlaufenden Monitorings (Deltawerte) der Umgebung bewerten.
Bewertet wird wie bereit einmal erwähnt:
* Integrität (Datenträger)
* Datendurchsatz Engpässe (Zukünftige Weiterentwicklung)
* Eine Art Kosten-Nutzenrechnung (Messung eines Buildvorgangs und den dafür extra bereitgestellten Datenträger) meiner Priorisierung der Buildprozesse (anhand eines Beispiels in Komplierung von `C`-Code)

## IST-Architektur

* [IST-Analyse (Hardware)](/src/IST-Analyse.sh)
* [SYS-Analyse (System & Storage)](/src/SYS-Analyse.sh)
* [Storage Info](/src/gather_storage_info.sh)
* [Build-Zeitmessung](/src/Messungen/Build_Time_Messung.sh)
* [IST-Architektur (Dokumentation)](/docs/IST-Architektur.md)

## SOLL-Architektur

* [SOLL-Architektur](/docs/SOLL-Architektur.md)

## Initalisierung

* [Storage-Einrichten](/docs/Storage-Einrichten.md)

## Betrieb

* [Storage-Administration](/docs/Storage-Administration.md)

## Messungen


*Es fehlt noch:*
  - fstrim
  - backup rsync
  - snapper
  - git setup
  - repo init und remote sync