{
  product: {
    id: 'SLES',
    registrationCode: '{{SCC_REGCODE}}'
  },
  user: {
    userName: 'bernhard',
    fullName: "Bernhard M. Wiedemann",
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true
  },
  root: {
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    sshPublicKey: '{{_SECRET_ED25519_PUB_KEY}}'
  },
  storage: {
    drives: [
      {
        partitions: [
          {
            filesystem: { path: '/' },
            size: '120 GiB'
          },
          {
            filesystem: { path: '/var/lib/libvirt/images/', type: 'xfs' }
          },
          {
            filesystem: { path: 'swap' },
            size: '4 GiB'
          }
        ]
      }
    ]
  },
  software: {
      patterns: {
        add: [
          'kvm_server',
          'kvm_tools'
        ],
      },
      packages: [
        'virt-bridge-setup',
        'libvirt-daemon'
      ]
  },
  scripts: {
    pre: [
      {
        name: 'wipefs',
        content: |||
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
        content: |||
          #!/usr/bin/env bash
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
          sshd_config_file="/etc/ssh/sshd_config.d/01-virt-test.conf"
          echo -e "TCPKeepAlive yes\nClientAliveInterval 60\nClientAliveCountMax 60" > $sshd_config_file
        |||
      },
      {
        name: "enable_persistent_journal_logging",
        content: |||
          #!/usr/bin/env bash
          echo -e "[Journal]\nStorage=persistent" > /etc/systemd/journald.conf.d/01-virt-test.conf
        |||
      },
      {
        name: "Configure_ssh_client",
        content: |||
          #!/usr/bin/env bash
          ssh_config_file="/etc/ssh/ssh_config.d/01-virt-test.conf"
          echo -e "StrictHostKeyChecking no\nUserKnownHostsFile /dev/null" > $ssh_config_file
        |||
      },
      {
        name: "Setup_root_ssh_keys",
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          mkdir -p -m 700 /root/.ssh
          echo '{{_SECRET_ED25519_PRIV_KEY}}' > /root/.ssh/id_ed25519
          sed -i 's/CR/\n/g' /root/.ssh/id_ed25519
          chmod 600 /root/.ssh/id_ed25519
          echo '{{_SECRET_ED25519_PUB_KEY}}' > /root/.ssh/id_ed25519.pub
        |||
      }
    ]
  }
}
