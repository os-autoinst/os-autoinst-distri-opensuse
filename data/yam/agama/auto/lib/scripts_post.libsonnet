{
  enable_root_login: {
    name: 'enable root login',
    chroot: true,
    content: |||
      #!/usr/bin/env bash
      echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
      #bsc#1257212 - sshd hasn't been activated after installation
      systemctl enable sshd
    |||
  },
  add_serial_console_hvc1: {
    name: 'add serial console hvc1 for ppc64le',
    chroot: true,
    content: |||
      #!/usr/bin/env bash
      systemctl enable serial-getty@hvc1
    |||
  },
  enable_kdump: {
    name: 'enable kdump',
    chroot: true,
    content: |||
      #!/usr/bin/env bash
      zypper -n in kdump
      systemctl enable kdump-commandline.service
      systemctl enable kdump.service
      kdumptool commandline -u
    |||
  }
}
