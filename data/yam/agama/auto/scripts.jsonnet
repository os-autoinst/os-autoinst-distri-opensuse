{
  scripts: {
    pre: [
      {
        name: 'disable questions',
        content: |||
          #!/usr/bin/env bash
          agama questions mode non-interactive
        |||
      }
    ],
    post: [
      {
        name: 'enable root login',
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
        |||
      }
    ]
  }
}
