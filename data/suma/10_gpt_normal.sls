partitioning:
    disk1:
        type: DISK
        device: /dev/sda
        disklabel: gpt
        partitions:
            p1:
                 size_MiB: 10
                 flags: bios_grub
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
            p5:
                 size_MiB: 2000
                 flags: swap
                 format: ext4
                 mountpoint: /data2

