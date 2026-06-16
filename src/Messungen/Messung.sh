sudo fio --name=seq-read --filename=/dev/sdc --ioengine=libaio \
  --rw=read --bs=128k --size=100% --numjobs=1 --iodepth=8

# Optional: Sequential lesen über die ganze Platte
sudo fio --name=seq-read --filename=/dev/sdc --ioengine=libaio \
  --rw=read --bs=128k --size=100% --numjobs=1 --iodepth=8



1. SSD Performance Benchmark
Für aussagekräftige Benchmarks von SSDs unter Linux ist fio (Flexible I/O Tester) der Standard. Es bietet volle Kontrolle über Blockgrößen, I/O-Tiefe und Zugriffsmuster.

Befehl für einen Standard-Test:
        fio --name=random-write --ioengine=libaio --rw=randwrite --bs=4k --size=1G --numjobs=1 --iodepth=32 --runtime=60 --time_based --end_fsync=1
* --rw=randwrite: Testet wahlfreie Schreibzugriffe.
* --bs=4k: Blockgröße, repräsentativ für typische OS-Operationen.
* --iodepth=32: Simuliert parallele Anfragen (Queue Depth).


fio --name=random-write --ioengine=libaio --rw=randwrite --bs=4k --size=1G --numjobs=1 --iodepth=32 --runtime=60 --time_based --end_fsync=1
