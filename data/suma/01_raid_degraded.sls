partitioning:
    disk1:
        type: DISK
        device: /dev/sda
        disklabel: msdos
        partitions:
            p1:
                 size_MiB: 2000
                 type: fd
            p2:
                 size_MiB: 2000
                 type: 82
                 format: swap
            p3:
                 type: 83
                 mountpoint: /
                 image: JeOS
            p4:
                 size_MiB: 2000
                 type: 83
                 format: btrfs
                 mountpoint: /data
                 luks_pass: 1234


    md0:
        type: RAID
        level: 1
        devices:
            - disk1p1
            - missing

        disklabel: msdos
        partitions:
            p1:
                type: 82
                format: ext4
                mountpoint: /data2

