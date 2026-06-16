#!/bin/env bash
# I/O-Monitoring skript
## Beschreibung
# 1. Muss manuell gestartet werden nach Systemboot
# Genutzte Tool: iostat, libvior




| Tool | Befehl | Zweck |
| --- | --- | --- |
| iostat | iostat -x 2 | Zeigt I/O-Last pro Gerät (z. B. /dev/sdc, /dev/nvme0n1p3). |
| iotop | sudo iotop -o | Zeigt I/O-Nutzung pro Prozess (z. B. qemu-kvm). |
| vmstat | vmstat 2 | Zeigt System-I/O, CPU und Speicher. |
| dstat | dstat -d | Echtzeit-I/O-Statistiken. |
| libvirt | virsh domstats <vm-name> --interface | Zeigt I/O-Statistiken für eine bestimmte VM. |
