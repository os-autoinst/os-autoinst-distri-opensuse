{
  "bootloader": {
    "stopOnBootMenu": false
  },
  "hostname": {
    "transient": "sles-16-64-kvm-hvm-uefi-agama-online-iso",
    "static": ""
  },
  "user": {
    "fullName": "QE Virtualization Functional Test",
    "password": "$2a$10$v32/h9hPd9cATZgLI/a1AepB9eQuMbjvNBOxQIla19fmAMjznSczG",
    "hashedPassword": true,
    "userName": "qevirt"
  },
  "root": {
    "password": "$2a$10$2qfKlKzzEp9tl3mde5CmhuxsEPd3DdlfJMQ.PNSI3rqXx4KztGYT6",
    "hashedPassword": true,
    "sshPublicKey": "##Authorized-Keys##"
  },
  "software": {
    "patterns": [
      "base"
    ],
    "packages": []
  },
  "product": {
    "id": "SLES",
    "registrationCode": "##Registration-Code##",
    "registrationEmail": "www@suse.com",
  },
  "legacyAutoyastStorage": [
    {
      "device": "/dev/vda",
      "disklabel": "##Disk-Label##",
      "enable_snapshots": true,
      "initialize": true,
      "use": "all"
    }
  ],
  "network": {
    "connections": [
      {
        "id": "Wired Connection",
        "method4": "auto",
        "method6": "auto",
        "ignoreAutoDns": false,
        "status": "up",
        "autoconnect": true,
        "persistent": true
      }
    ]
  },
  "localization": {
    "language": "en_US.UTF-8",
    "keyboard": "us",
    "timezone": "Europe/Berlin"
  },
  "scripts": {
    "post": [
      {
        "name": "persistent_hostname",
        "content": "#!/usr/bin/env bash\necho -e \"sles-16-64-kvm-hvm-uefi-agama-online-iso.testvirt.net\" > /etc/hostname\n"
      },
      {
        "name": "sshd_config",
        "content": "#!/usr/bin/env bash\necho -e \"PermitRootLogin yes\\nPubkeyAuthentication yes\\nPasswordAuthentication yes\\nPermitEmptyPasswords no\\nTCPKeepAlive yes\\nClientAliveInterval 60\\nClientAliveCountMax 60\" > /etc/ssh/sshd_config.d/01-qe-virtualization-functional.conf\n",
        "chroot": true
      },
      {
        "name": "ssh_config",
        "content": "#!/usr/bin/env bash\necho -e \"StrictHostKeyChecking no\\nUserKnownHostsFile /dev/null\" > /etc/ssh/ssh_config.d/01-qe-virtualization-functional.conf\n"
      },
      {
        "name": "persistent_journal_logging",
        "content": "#!/usr/bin/env bash\necho -e \"[Journal]\\\\nStorage=persistent\" > /etc/systemd/journald.conf.d/01-qe-virtualization-functional.conf\n"
      }
    ]
  }
}
