Testplan pro Partition

0.Log-Größen überdenken

# 64m für /var/log ist zu großzügig
# XFS-Log wird nur für Metadata-Journaling genutzt, nicht für Daten
# Faustregel: max(32m, Partitionsgröße / 512)
# Bei ~20GB /var/log → 40m → abrunden auf 32m reicht
-l size=32m

# 128m für libvirt nur sinnvoll wenn du viele gleichzeitige VMs hast
# Bei 1-2 VMs: 64m ausreichend

0. udev-Regel
# FALSCH — greift auf alle rotational==0 Devices
ACTION=="add|change", KERNEL=="sdc", ATTR{queue/rotational}=="0", \
  ATTR{queue/scheduler}="mq-deadline"

# RICHTIG — sdc ist bereits spezifisch genug, rotational-Check redundant
# aber wenn du es allgemeiner haben willst (alle SSDs), dann KERNEL weglassen:
ACTION=="add|change", ATTR{queue/rotational}=="0", \
  ATTR{queue/scheduler}="mq-deadline"

# Für device-spezifische Regel besser per ID statt Kernel-Name
# sdc kann sich nach Reboot ändern!
ACTION=="add|change", ENV{ID_SERIAL}=="Samsung_SSD_850_PRO_*", \
  ATTR{queue/scheduler}="mq-deadline", \
  ATTR{queue/read_ahead_kb}="128", \
  ATTR{queue/nr_requests}="64"

# Den Serial erhalten mit
	
	udevadm info --query=all --name=/dev/sdc | grep ID_SERIAL

0. sysctl
	vm.dirty_writeback_centisecs = 1500   # 15s Kompromiss
	vm.dirty_expire_centisecs = 3000      # Daten dürfen 30s alt werden

0.
# agcount = min(4, Partitionsgröße_in_GB / 10)

# Für VM-Images (große Extents)
sudo mkfs.xfs -f -d agcount=2 -l size=128m /dev/sdcX

# Für cache/build (kleinere Allokationseinheiten)
sudo mkfs.xfs -f -b size=4096 /dev/sdcX

1. Partition mounten (mit exakt deinen fstab-Optionen)
UUID=... /var/lib/libvirt xfs defaults,nodev,nosuid,allocsize=64m,nofail 0 0
UUID=... /home/giant/.cache/build xfs defaults,nodev,nosuid,noexec,noatime,largeio 0 0
UUID=... /home/giant/.cache/ccache xfs defaults,nodev,nosuid,noexec,noatime,largeio 0 0


2. fio-Tests anpassen je nach Use-Case
- `/var/lib/libvirt/` - mixed random
	
	sudo fio --name=vm-sim \
  	--directory=/mnt/test \
  	--ioengine=libaio \
  	--rw=randrw --rwmixread=70 \
  	--bs=64k --size=2G \
  --numjobs=2 --iodepth=64 \
  --runtime=60 --time_based \
  --end_fsync=1

- `/var/log` - kleine Appends

	sudo fio --name=log-sim \
  --directory=/mnt/test \
  --ioengine=sync \
  --rw=write --bs=4k \
  --size=512M --numjobs=4 \
  --fsync=1

- `ccache`/`build` - viele kleine Dateien
	sudo fio --name=metadata-heavy \
  --directory=/mnt/test \
  --ioengine=libaio \
  --rw=randwrite --bs=4k \
  --size=256M --numjobs=8 \
  --iodepth=16 --runtime=60 \
  --time_based

- `/var/cache` - noatime,hoher Durchsatz
	sudo fio --name=cache-sim \
  --directory=/mnt/test \
  --ioengine=libaio \
  --rw=randrw --rwmixread=50 \
  --bs=128k --size=1G \
  --numjobs=1 --iodepth=32 \
  --runtime=60 --time_based

3. Ergebnisse

bw (Bandbreite) → für libvirt und cache relevant
iops → für ccache/build/log relevant
lat avg + stdev → Stdev hoch = inkonsistentes Verhalten = problematisch für VMs
