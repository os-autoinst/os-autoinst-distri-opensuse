local root_filesystem(filesystem) = {
  drives: [
    {
      partitions: [
        { search: '*', delete: true },
        { generate: 'default' },
        { filesystem: { path: '/', type: filesystem } },
      ],
    },
  ],
};

local lvm(encrypted=false, encryption='luks2') = {
  drives: [
    {
      alias: 'pvs-disk',
      partitions: [
        { search: '*', delete: true },
      ],
    },
  ],
  volumeGroups: [
    {
      name: 'system',
      physicalVolumes: [
        {
          [if encrypted == true then 'generate']: {
            targetDevices: ['pvs-disk'],
            encryption: {
              [encryption]: { password: 'nots3cr3t' },
            },
          },
          [if encrypted == false then 'generate']: ['pvs-disk'],
        },
      ],
      logicalVolumes: [
        { generate: 'default' },
      ],
    },
  ],
};

local whole_disk_and_boot_unattended() = {
  drives: [
    {
      search: '/dev/vda',
      filesystem: {
        path: '/home',
      },
    },
    {
      search: '/dev/vdb',
      partitions: [
        {
          filesystem: {
            path: '/',
          },
        },
      ],
    },
    {
      search: '/dev/vdc',
      alias: 'boot-disk',
    },
  ],
  boot: {
    configure: 'true',
    device: 'boot-disk',
  },
};

local raid(level='0') = {
  drives: [
    {
      partitions: [
        { search: '*', delete: true },
        { id: 'bios_boot', size: '8 MiB', boot: true },
        { alias: 'first-raid', id: 'raid', size: '7.81 GiB' },
        { alias: 'second-raid', id: 'raid', size: '512 MiB' },
      ],
      mdRaids: [
        {
          level: level,
          devices: ['first-raid'],
          partitions: [
            {
              filesystem: {
                path: '/',
                type: { btrfs: { snapshots: false } },
              },
              boot: true,
            },
          ],
        },
        {
          level: 'raid0',
          devices: ['second-raid'],
          partitions: [
            { filesystem: { path: 'swap' } },
          ],
        },
      ],
    },
  ],
};

{
  lvm: lvm(false),
  lvm_encrypted: lvm(true),
  lvm_tpm_fde: lvm(true, 'tpmFde'),
  raid0: raid('0'),
  root_filesystem_ext4: root_filesystem('ext4'),
  root_filesystem_xfs: root_filesystem('xfs'),
  whole_disk_and_boot_unattended: whole_disk_and_boot_unattended(),
}
