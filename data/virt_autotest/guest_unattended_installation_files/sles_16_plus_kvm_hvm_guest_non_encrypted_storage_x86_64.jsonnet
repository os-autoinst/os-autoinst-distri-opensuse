{
  "localization": {
    "language": "en_US.UTF-8",
    "keyboard": "us",
    "timezone": "Europe/Berlin"
  },
  product: {
    id: "SLES",
    registrationCode: "##Registration-Code##", 
    registrationEmail: "www@suse.com"
  },
  "bootloader": {
    "stopOnBootMenu": false
  },
  "user": {
    "fullName": "QE Virtualization Functional Test",
    "userName": "qevirt",
    "password": "$2a$10$v32/h9hPd9cATZgLI/a1AepB9eQuMbjvNBOxQIla19fmAMjznSczG",
    "hashedPassword": true,
    "autologin": false
  },
  "root": {
    "password": "$2a$10$2qfKlKzzEp9tl3mde5CmhuxsEPd3DdlfJMQ.PNSI3rqXx4KztGYT6",
    "hashedPassword": true,
    "sshPublicKey": "##Authorized-Keys##"
  },
  legacyAutoyastStorage: [
      {
         "device": "/dev/vda",
         "disklabel": "##Disk-Label##",
         "enable_snapshots": true,
         "initialize": true,
         use: "all"
      }
  ],
  "storage": {
    "drives": [
      {
        "partitions": [
          { "filesystem": { "path": "/" } },
          { "filesystem": { "path": "/home" } },
          { "filesystem": { "path": "swap" } }
        ]
      }
    ]
  },
  "software": {
      patterns: [
         'base'
      ]
  },
  "network": {
    "connections": [
      {
        "id": "Wired Connection",
        "method4": "auto",
        "method6": "auto",
        "ignoreAutoDns": false,
        "status": "up",
        "autoconnect": true,
        "dns_searchlist": [
          "##Domain-Name##",
          "suse.de",
          "suse.asia",
          "opensuse.org"
        ]
      }
    ]
  },
  scripts: {
    post: [
      {
        name: "persistent_hostname",
        content: |||
          #!/usr/bin/env bash
          echo -e "##Host-Name##.##Domain-Name##" > /etc/hostname
        |||
      },
      {
        name: "sshd_config",
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          echo -e "PermitRootLogin yes\nPubkeyAuthentication yes\nPasswordAuthentication yes\nPermitEmptyPasswords no\nTCPKeepAlive yes\nClientAliveInterval 60\nClientAliveCountMax 60" > /etc/ssh/sshd_config.d/01-qe-virtualization-functional.conf
        |||
      },
      {
        name: "ssh_config",
        content: |||
          #!/usr/bin/env bash
          echo -e "StrictHostKeyChecking no\nUserKnownHostsFile /dev/null" > /etc/ssh/ssh_config.d/01-qe-virtualization-functional.conf
        |||
      },
      {
        name: "persistent_journal_logging",
        content: |||
          #!/usr/bin/env bash
          echo -e "[Journal]\\nStorage=persistent" > /etc/systemd/journald.conf.d/01-qe-virtualization-functional.conf
        |||
      }
    ]
  }
}
