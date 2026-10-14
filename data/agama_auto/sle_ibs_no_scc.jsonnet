local arch = '{{ARCH}}';
local version = '{{VERSION}}';
{
  product: {
    id: '{{AGAMA_PRODUCT_ID}}',
    registrationCode: '{{SCC_REGCODE}}'
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
    hashedPassword: true,
    sshPublicKey: 'fake public key to enable sshd and open firewall'
  },
  software: {
    packages: ['openssh-server-config-rootlogin'],
    patterns: ['base', 'minimal_base', 'selinux'],
    extraRepositories: [
      {
        alias: "SLES::%s::product" % [version],
        url: "http://dist.suse.de/ibs/SUSE:/SLFO:/Products:/SLES:/%s:/TEST/product/repo/SLES-%s-%s" % [version, version, arch],
        allowUnsigned: true
      }
    ],
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
        name: 'Unregister the system',
        chroot: true,
        content: |||
          #!/usr/bin/env bash
          SUSEConnect -d || SUSEConnect --cleanup
        |||
      }
    ]
  }
}
