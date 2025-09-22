local repo = '{{INCIDENT_REPO}}';
local urls = if repo != '' then std.split(repo, ',') else [];
{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
    registrationCode: '{{SCC_REGCODE}}',
    addons: [
      {
        id: 'PackageHub',
      }
    ]
  },
  bootloader: {
    stopOnBootMenu: true,
  },
  user: {
    fullName: 'Bernhard M. Wiedemann',
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    userName: 'bernhard'
  },
  root: {
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true
  },
  software: {
    packages: [],
    patterns: [
      'base',
      'kvm_server',
      'kvm_tools'
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
          echo -e "TCPKeepAlive yes\nClientAliveInterval 60\nClientAliveCountMax 60" > $sshd_config_file
        |||
      }
    ]
  }
}