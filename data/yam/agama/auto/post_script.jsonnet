{
  "scripts": {
    "post": [
      {
        "name": "enable root login",
        "chroot": true,
        "body": |||
          #!/usr/bin/env bash
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
        |||
      }
    ]
  }
}
