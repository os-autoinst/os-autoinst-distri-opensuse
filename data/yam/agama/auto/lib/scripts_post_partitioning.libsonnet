{
  create_zypp_conf: {
    name: 'create zypper.conf',
    content: |||
      #!/usr/bin/env bash
      mkdir -vp /mnt/etc/zypp
      echo '# QE-Yam Test' > /mnt/etc/zypp/zypper.conf
    |||
  }
}
