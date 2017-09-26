partitioning:
    disk1:
        type: DISK
        device: /dev/sda
        disklabel: msdos
        partitions:
            p1:
                 size_MiB: 2000
                 type: 82
                 format: swap
            p2:
                 type: 83
                 mountpoint: /
                 image: JeOS
            p3:
                 size_MiB: 2000
                 type: 83
                 format: btrfs
                 mountpoint: /data
                 luks_pass: 1234
            p4:
                 size_MiB: 2000
                 type: 82
                 format: ext4
                 mountpoint: /data2

