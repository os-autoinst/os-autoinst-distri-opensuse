local repo = '{{INCIDENT_REPO}}';
local urls = if repo != '' then std.split(repo, ',') else [];
{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
    registrationCode: '{{SCC_REGCODE}}',
    addons: []
  },
  bootloader: {
    stopOnBootMenu: false,
  },
  user: {
    fullName: 'Bernhard M. Wiedemann',
    password: '$6$0bUrc6YvA/qw$h1Z3pzadaxmc/KgcHRSEcYoU1ShVNymoXBaRAQZJ4ozVhTbCvdAMbGQrQAAX7cC9cLRybhsvDio3kBX/IB3xj/',
    hashedPassword: true,
    userName: 'bernhard'
  },
  root: {
    password: '$6$0bUrc6YvA/qw$h1Z3pzadaxmc/KgcHRSEcYoU1ShVNymoXBaRAQZJ4ozVhTbCvdAMbGQrQAAX7cC9cLRybhsvDio3kBX/IB3xj/',
    hashedPassword: true,
    sshPublicKey: '{{_SECRET_RSA_PUB_KEY}}'
  },
  software: {
    packages: [],
    patterns: [
      'base'
    ],
    extraRepositories:
      if std.length(urls) > 0 then
        [
          {
            alias: 'TEST_' + std.toString(i),
            url: urls[i],
            allowUnsigned: true
          }
          for i in std.range(0, std.length(urls) -1)
        ]
      else
        [],
    onlyRequired: false
  },
  questions: {
    policy: 'auto',
    answers: [
      {
        answer: 'Trust',
        class: 'software.import_gpg'
      }
    ]
  },
  scripts: {
    post: [
      {
        name: 'setup_sshd',
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          systemctl enable sshd
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
          sshd_config_file="/etc/ssh/sshd_config.d/01-virt-test.conf"
          echo -e "TCPKeepAlive yes\nClientAliveInterval 60\nClientAliveCountMax 120" > $sshd_config_file
        |||
      },
      {
        name: 'report_ip_address',
        chroot: false,
        content: |||
          #!/usr/bin/env bash
          # Report IP address to test host using guest name
          # Try eth0 first (most common), then fallback to first available interface
          ip a | grep eth0 | grep -Po '(?<=inet )[\d.]+' > /root/{{GUEST}} || \
          ip -4 addr show | grep -E "inet.*scope global" | head -1 | grep -Po '(?<=inet )[\d.]+' > /root/{{GUEST}}
          logger "SLES16 Guest {{GUEST}} IP is written into file: $(cat /root/{{GUEST}} 2>/dev/null || echo 'FAILED')"
          curl -k -u root:{{PASS}} -T /root/{{GUEST}} sftp://{{SUT_IP}}/tmp/guests_ip/ --ftp-create-dirs
          exit 0
        |||
      }
    ]
  }
}
