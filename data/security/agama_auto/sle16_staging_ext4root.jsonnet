local repo = '{{INCIDENT_REPO}}';
local urls = std.split(repo, ',');
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
  storage: {
    drives: [
      {
        partitions: [
          { search: '*', delete: true },
          { generate: 'default' },
          { filesystem: { path: '/', type: 'ext4' } },
        ],
      },
    ],
  },
  software: {
    packages: [],
    extraRepositories:
      if repo != '' then
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
        name: 'enable sshd',
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          systemctl enable sshd
        |||
      }
    ]
  }
}
