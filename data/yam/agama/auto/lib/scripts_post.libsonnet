{
  enable_root_login: {
    name: 'enable root login',
    chroot: true,
    content: |||
      #!/usr/bin/env bash
      echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
    |||
  },
  enable_gdm: {
  name: 'enable gdm login',
  chroot: true,
  content: |||
    #!/usr/bin/env bash
    systemctl enable gdm
  |||
  }
}
