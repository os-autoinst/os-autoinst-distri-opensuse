local disk_id = '{{INSTALL_DISK_WWN}}';
local partitions_config = {
  partitions: [{ generate: 'default' }],
  [if disk_id != '' then 'search']: '/dev/disk/by-id/' + disk_id
};
{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
    registrationCode: '{{SCC_REGCODE}}'
  },
  bootloader: {
    timeout: 45,
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
  software: {
    packages: ['openssh-server-config-rootlogin'],
  },
  storage: {
    drives: [
      partitions_config
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
              parted -s /dev/$i mklabel gpt
              sync
          done
        |||
      }
    ],
    post: [
      {
        name: 'set grub terminal to console',
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          sed -i 's/^GRUB_TERMINAL=.*/GRUB_TERMINAL=\"console\"/' /etc/default/grub
          update-bootloader --refresh
        |||
      }
    ]
  }
}
