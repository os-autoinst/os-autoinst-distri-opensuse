{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
  },
  bootloader: {
    stopOnBootMenu: true
  },
  root: {
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    sshPublicKey: 'enable ssh',
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
