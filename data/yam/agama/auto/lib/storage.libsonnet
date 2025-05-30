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
local raid(raid_type='raid0') = {
  drives: [
    {
      search: '*',
      partitions: [
        {
          delete: true,
          search: '*',
        },
        {
          id: 'bios_boot',
          size: '8 MiB',
        },
        {
          alias: 'mdroot',
          id: 'raid',
          size: '7.81 GiB',
        },
        {
          alias: 'mdswap',
          id: 'raid',
          size: '512 MiB',
        },
      ],
    },
  ],
  mdRaids: [
    {
      devices: ['mdroot'],
      level: raid_type,
      partitions: [
        {
          filesystem: {
            path: '/',
            type: {
              btrfs: { snapshots: false },
            },
          },
        },
      ],
    },
    {
      devices: ['mdswap'],
      level: 'raid0',
      partitions: [
        {
          filesystem: { path: 'swap' },
        },
      ],
    },
  ],
};

local raid_uefi(raid_type='raid0') = {
  drives: [
    {
      partitions: [
        {
          delete: true,
          search: '*',
        },
        {
          filesystem: {
            path: '/boot/efi',
            type: 'vfat',
          },
          id: 'esp',
          size: '128 MiB',
        },
        {
          alias: 'mdroot',
          id: 'raid',
          size: '7.81 GiB',
        },
        {
          alias: 'mdswap',
          id: 'raid',
          size: '512 MiB',
        },
      ],
    },
    {
      partitions: [
        {
          delete: true,
          search: '*',
        },
        {
          filesystem: {
            type: 'vfat',
          },
          id: 'esp',
          size: '128 MiB',
        },
        {
          alias: 'mdroot',
          id: 'raid',
          size: '7.81 GiB',
        },
        {
          alias: 'mdswap',
          id: 'raid',
          size: '512 MiB',
        },
      ],
      search: '*',
    },
  ],
  mdRaids: [
    {
      devices: [
        'mdroot',
      ],
      level: raid_type,
      partitions: [
        {
          filesystem: {
            path: '/',
            type: {
              btrfs: {
                snapshots: false,
              },
            },
          },
        },
      ],
    },
    {
      devices: [
        'mdswap',
      ],
      level: 'raid0',
      partitions: [
        {
          filesystem: {
            path: 'swap',
          },
        },
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
{
  lvm: lvm(false),
  lvm_encrypted: lvm(true),
  lvm_tpm_fde: lvm(true, 'tpmFde'),
  root_filesystem_ext4: root_filesystem('ext4'),
  root_filesystem_xfs: root_filesystem('xfs'),
  raid0: raid('raid0'),
  raid0_uefi: raid_uefi('raid0'),
  whole_disk_and_boot_unattended: whole_disk_and_boot_unattended(),
}
