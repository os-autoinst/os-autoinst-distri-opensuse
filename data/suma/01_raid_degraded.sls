partitioning:
    disk1:
        type: DISK
        device: /dev/sda
        disklabel: msdos
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
            p4:
                 size_MiB: 2000
                 flags: 
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
                flags: swap
                format: ext4
                mountpoint: /data2

