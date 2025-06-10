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
    pre: [
      {
        name: 'disable questions',
        content: |||
          #!/usr/bin/env bash
          agama questions mode non-interactive
        |||
      }
    ],
    post: [
      {
        name: 'enable root login',
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
        |||,
      },
    ],
  },
}
