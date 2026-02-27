{
  "root": {
    "password": "$5$yWyONd1vdHjF/ZUp$HDJnaXL8B/zPAenwqBLUiPJfAw/L.emrVoSHX/LjkwA",
    "hashedPassword": true
  },
  "software": {
    "patterns": {
        add: ["kvm_server", "kvm_tools"]
    }
  },
  "product": {
    "id": "SLES",
  },
  "storage": {
    "drives": [
      {
        "search": "/dev/disk/by-id/{{OSDISK}}",
        "partitions": [
          {
            "search": "/dev/disk/by-id/{{OSDISK}}-part2",
            "filesystem": { "path": "swap" }
          },
          { "search": "/dev/disk/by-id/{{OSDISK}}-part{{DISKID}}", "delete": true },
          {
            "size": "64424509440",
            "filesystem": {
              "path": "/",
              "type": { "btrfs": { "snapshots": true } },
              "label": "{{MILESTONENAME}}"
            }
          }
        ]
      }
    ]
  },
  "localization": {
    "language": "en_US.UTF-8",
    "keyboard": "us",
    "timezone": "Asia/Shanghai"
  },
  "scripts": {
    "post": [
      {
        "name": "enable-sshd",
        chroot: true,
        content: |||
          #!/usr/bin/bash
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
          systemctl enable sshd.service
          systemctl start sshd.service
        |||
      }
    ]
  }
}
