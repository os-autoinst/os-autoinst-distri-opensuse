partitioning:
    disk1:
        type: DISK
        device: /dev/sda
        disklabel: gpt
        partitions:
            p1:
                 size_MiB: 2000
                 flags: raid
            p2:
                 size_MiB: 2000
                 flags: swap
                 format: swap
            p3:
                 flags: 
                 mountpoint: /
                 image: JeOS

    md0:
        type: RAID
        level: 1
        devices:
            - disk1p1
            - disk1p4

        disklabel: msdos
        partitions:
            p1:
                flags: swap
                format: ext4
                mountpoint: /data2

