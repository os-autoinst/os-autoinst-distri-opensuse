{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
    registrationCode: '{{SCC_REGCODE}}',
    mode: 'immutable',
  },
  bootloader: {
    stopOnBootMenu: false,
  },
  user: {
    fullName: 'Bernhard M. Wiedemann',
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    userName: 'bernhard'
  },
  root: {
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    sshPublicKey: 'fake public key to enable sshd and open firewall'
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
            filesystem: { path: 'swap' },
            size: '4 GiB'
          }
        ]
      }
    ]
  },
  software: {
    packages: ['curl', 'wget', 'acl', 'openssh-server-config-rootlogin'],
  },
  scripts: {
    pre: [
      {
        name: 'wipefs',
        content: |||
          #!/usr/bin/env bash
          for i in `lsblk -n -l -o NAME -d -e 7,11,254`
              do wipefs -af /dev/$i
              # The following 4 lines work around Agama race condition on NVMe devices.
              # See bsc#1269730 and PR#25926
              partprobe /dev/$i 2>/dev/null
              blockdev --rereadpt /dev/$i 2>/dev/null
          done
          udevadm settle --timeout=30
          sync
          sleep 2
        |||
      }
    ],
    post: [
      {
        name: 'set grub terminal to console',
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          set -e
          sed -i 's/^GRUB_TERMINAL=.*/GRUB_TERMINAL="console"/' /etc/default/grub
          update-bootloader --refresh
        |||
      },
      {
        name: 'switch_to_kernel_64kb',
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          set -e
          zypper --non-interactive install kernel-64kb
          zypper --non-interactive remove kernel-default
        |||
      }
    ]
  }
}
