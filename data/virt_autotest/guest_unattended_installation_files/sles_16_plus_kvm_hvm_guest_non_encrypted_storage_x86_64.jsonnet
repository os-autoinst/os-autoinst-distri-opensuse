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
    "hashedPassword": true
  },
  "root": {
    "password": "$2a$10$2qfKlKzzEp9tl3mde5CmhuxsEPd3DdlfJMQ.PNSI3rqXx4KztGYT6",
    "hashedPassword": true,
    "sshPublicKey": "##Authorized-Keys##"
  },
  // Workaround for bsc#1257492
  "software": {
      "packages": [
        'qemu-guest-agent'
      ]
  },
  "storage": {
    "drives": [
      {
        "partitions": [
          {
            "search": { "ifNotFound": "skip" },
            "delete": true
          },
          {
            "filesystem": { "path": "/" },
            "size": { "min": "20 GiB" }
          },
          {
            "filesystem": { "path": "swap" },
            "size": "4 GiB"
          },
          {
            "filesystem": { "path": "/home" },
            "size": "6 GiB"
          }
        ]
      }
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
        "dnsSearchlist": [
          "##Domain-Name##",
          "suse.de",
          "suse.asia",
          "opensuse.org"
        ]
      }
    ],
    "state": {}
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
          mkdir -p /etc/ssh/ssh_config.d
          echo -e "StrictHostKeyChecking no\nUserKnownHostsFile /dev/null\nLogLevel ERROR" > /etc/ssh/ssh_config.d/01-qe-virtualization-functional.conf
        |||
      },
      {
        name: "persistent_journal_logging",
        content: |||
          #!/usr/bin/env bash
          echo -e "[Journal]\\nStorage=persistent" > /etc/systemd/journald.conf.d/01-qe-virtualization-functional.conf
        |||
      },
      {
        name: "enable_sshd",
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          systemctl enable sshd.service
        |||
      }
    ]
  }
}
