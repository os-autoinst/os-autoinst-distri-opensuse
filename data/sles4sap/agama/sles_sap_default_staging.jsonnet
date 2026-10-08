local repo = '{{INCIDENT_REPO}}';
local urls = std.split(repo, ",");
local desktop = '{{DESKTOP}}';
local product_id = '{{AGAMA_PRODUCT_ID}}';
{
  product: {
    id: product_id,
    registrationCode: if product_id == 'SLES' then '{{SCC_REGCODE}}' else '{{SCC_REGCODE_SLES4SAP}}',
  },
  bootloader: {
    stopOnBootMenu: true
  },
  root: {
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    sshPublicKey: 'enable ssh',
  },
  [if desktop == 'gnome' then 'user']: {
    fullName: 'Bernhard M. Wiedemann',
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    userName: 'bernhard'
  },
  software: {
    packages: [],
    [if desktop == 'gnome' then 'patterns']: {
      add: ['gnome']
    },
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
  scripts: {
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
