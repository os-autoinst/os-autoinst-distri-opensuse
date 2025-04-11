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
  "storage": {
    "drives": [
      {
        "search": "/dev/vda",
        "partitions": [
          { 
            "search": "/dev/vda2",
            "filesystem": { "path": "/" },
            "size": {
              "min": "2 GiB",
              "max": "current"
            }
          },
          {
            "search": "/dev/vda3",
            "filesystem": { "path": "swap" },
            "size": "1 GiB"
          },
          { 
            "filesystem": { "path": "/home" },
            "encryption": {
              "luks2": { "password": "nots3cr3t" }
            }
          },
        ],
      },
    ],
  },
}
