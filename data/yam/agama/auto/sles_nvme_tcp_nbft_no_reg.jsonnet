// Root file system on the NVMe/TCP namespace that the NBFT describes.
// The firmware of the guest cannot read NVMe/TCP, so the ESP and /boot
// stay on the local disk.
{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
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
        search: '/dev/vda',
        alias: 'local-disk',
        partitions: [
          { search: '*', delete: true },
          { filesystem: { path: '/boot', type: 'xfs' }, size: '1 GiB' },
        ],
      },
      {
        search: '/dev/nvme0n1',
        partitions: [
          { search: '*', delete: true },
          { filesystem: { path: '/' } },
        ],
      },
    ],
    boot: {
      configure: true,
      device: 'local-disk',
    },
  },
  scripts: {
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
