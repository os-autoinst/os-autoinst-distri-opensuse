{
  bootloader: {
    stopOnBootMenu: true,
  },
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
    registrationCode: '{{SCC_REGCODE}}',
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
          { generate: ['pvs-disk'] },
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
