{
  bootloader: {
    stopOnBootMenu: true,
  },
  product: {
    id: 'SLES',
    registrationCode: 'xxxx',
   },
  root: {
    hashedPassword: true,
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
  },
  scripts: {
    post: [
       {
          content: "#!/usr/bin/env bash\necho 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf\n",
          chroot: true,
          name: 'enable root login',
       },
     ],
   },
  storage: {
    drives: [
      {
        search: '/dev/vdb',
        partitions: [
          { generate: 'default' },
        ],
      },
    ],
  },
  user: {
    fullName: 'Bernhard M. Wiedemann',
    hashedPassword: true,
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    userName: 'bernhard',
  },
}
