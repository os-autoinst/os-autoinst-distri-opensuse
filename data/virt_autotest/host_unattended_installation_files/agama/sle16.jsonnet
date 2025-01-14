{
  product: {
    id: 'SLES'
  },
  user: {
    userName: 'bernhard',
    fullName: "Bernhard M. Wiedemann",
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true
  },
  root: {
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true
  },
  legacyAutoyastStorage: [
      {
         "device": "/dev/sda",
         "disklabel": "gpt",
         "enable_snapshots": false,
         "initialize": true,
         "partitions": [
            {
               "create": true,
               "filesystem": "vfat",
               "format": true,
               "mount": "/boot/efi",
               "mountby": "uuid",
               "partition_id": 259,
               "size": "512M"
            },
            {
               "create": true,
               "create_subvolumes": true,
               "filesystem": "btrfs",
               "format": true,
               "mount": "/",
               "mountby": "uuid",
               "partition_id": 131,
               "size": "120G"
            },
            {
               "create": true,
               "filesystem": "xfs",
               "format": true,
               "mount": "/var/lib/libvirt/images/",
               "mountby": "uuid",
               "partition_id": 131,
               "resize": false
            },
            {
               "create": true,
               "filesystem": "swap",
               "format": true,
               "mountby": "uuid",
               "size": "4G"
            }
         ],
         type: "CT_DISK",
         use: "all"
      }
  ],
  software: {
      patterns: [
         'base',
         'kvm_host'
      ]
  },
  scripts: {
    pre: [
      {
        name: 'wipefs',
        body: |||
          #!/usr/bin/env bash
          for i in `lsblk -n -l -o NAME -d -e 7,11,254`
              do wipefs -af /dev/$i
              sleep 1
              sync
          done
        |||
      }
    ],
    post: [
      {
        name: "config_sshd",
        chroot: true,
        body: |||
          #!/usr/bin/env bash
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
          sshd_config_file="/etc/ssh/sshd_config.d/01-virt-test.conf"
          echo -e "TCPKeepAlive yes\nClientAliveInterval 60\nClientAliveCountMax 60" > $sshd_config_file
        |||
      },
      {
        name: "enable_persistent_journal_logging",
        body: |||
          #!/usr/bin/env bash
          echo -e "[Journal]\\nStorage=persistent" > /etc/systemd/journald.conf.d/01-virt-test.conf
        |||
      },
      {
        name: "Configure_ssh_client",
        body: |||
          #!/usr/bin/env bash
          ssh_config_file="/etc/ssh/ssh_config.d/01-virt-test.conf"
          echo -e "\StrictHostKeyChecking no\nUserKnownHostsFile /dev/null" > $ssh_config_file
        |||
      }
    ]
  }
}
