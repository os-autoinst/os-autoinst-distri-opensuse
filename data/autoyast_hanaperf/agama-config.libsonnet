// This libsonnet is used for generating unattended agama profile.
// ARCH comes from openQA ARCH: x86_64, ppc64le and so on.
// BUILD comes from openQA BUILD: GM, 40.1 and so on.
// OSDISK comes from openQA OSDISK: sda, scsi-SATA_DELLBOSS_VD_b68e1f8449390010 and so on.
// SCC_REGCODE comes from openQA SCC_REGCODE
// ARCH,BUILD and OSDISK are mandatory parameters and set via openQA AGAMA_PROFILE_OPTIONS
function(ARCH='', BUILD='', OSDISK='', SCC_REGCODE='') {
  user: {
    fullName: 'Bernhard M. Wiedemann',
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    userName: 'bernhard',
  },
  root: {
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    sshPublicKey: 'fake public key to enable sshd and open firewall',
  },
  software: {
    packages: ['patterns-sap-minimal_sap','openssh-server-config-rootlogin'],
  },
  [if ARCH == 'x86_64' then 'bootloader']: {
    extraKernelParams: 'tsx=auto intel_idle.max_cstate=1 panic=30',
  },
  product: {
    id: 'SLES',
    [if BUILD != 'GM' then 'registrationCode']: SCC_REGCODE,
  },
  storage: {
    drives: [
      {
        search: '/dev/disk/by-id/' + OSDISK,
        partitions: [
          { search: '*', delete: true },
          { generate: 'default' },
        ],
      },
    ],
  },
  localization: {
    language: 'en_US.UTF-8',
    keyboard: 'us',
    timezone: 'Asia/Shanghai',
  },
  scripts: {
    pre: [
      {
        name: 'wipefs',
        content: |||
          #!/usr/bin/env bash
          for i in `lsblk -n -l -o NAME -d -e 7,11,254`
              do wipefs -af /dev/$i
              sleep 1
              sync
          done
        |||,
      },
    ],
  },
}
