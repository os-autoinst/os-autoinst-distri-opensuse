{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
    registrationCode: '{{SCC_REGCODE}}',
  },
  bootloader: {
    stopOnBootMenu: true,
  },
  user: {
    fullName: 'Bernhard M. Wiedemann',
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    userName: 'bernhard',
  },
  root: {
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    sshPublicKey: 'fake public key to enable sshd and open firewall',
  },
  storage: {
    drives: [
      {
        alias: 'pvs-disk',
        partitions: [
          { search: '*', delete: true },
        ],
      },
    ],
    volumeGroups: [
      {
        name: 'system',
        physicalVolumes: [
          {
            generate: {
              targetDevices: ['pvs-disk'],
              encryption: {
                luks2: { password: 'nots3cr3t' },
              },
            },
          },
        ],
        logicalVolumes: [
          { generate: 'default' },
        ],
      },
    ],
  },
  scripts: {
    post: [
      {
        name: 'enable root login',
        chroot: true,
        body: |||
          #!/usr/bin/env bash
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
        |||,
      },
    ],
  },
}
