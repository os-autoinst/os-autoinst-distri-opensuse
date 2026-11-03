local repo = '{{INCIDENT_REPO}}';
local urls = std.split(repo, ",");
{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
    registrationCode: '{{SCC_REGCODE_SLES4SAP}}',
  },
  root: {
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    sshPublicKey: 'enable ssh',
  },
  software: {
    packages: [],
    extraRepositories:
      if repo != "" then
        [
          {
            alias: "TEST_" + std.toString(i),
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
  storage: {
    drives: [
      {
        search: '/dev/sda',
        partitions: [
          { search: '*', delete: true },
          { generate: 'default' },
        ],
      },
    ],
  },
  scripts: {
    pre: [
      {
        name: 'cleanup-storage',
        content: |||
          #!/usr/bin/env bash
          set -x
          swapoff -a
          umount -f /dev/sda* 2>/dev/null || true
          vgchange -an 2>/dev/null || true
          multipath -F 2>/dev/null || true
          for p in /dev/sda[0-9]*; do
            [ -b "$p" ] && wipefs -af "$p" || true
          done
          wipefs -af /dev/sda
          partprobe /dev/sda || true
          sync
        |||,
      },
    ],
    post: [
      {
        name: 'enable root login',
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          echo 'PermitRootLogin yes' > /etc/ssh/sshd_config.d/root.conf
        |||,
      },
    ],
  },
}
