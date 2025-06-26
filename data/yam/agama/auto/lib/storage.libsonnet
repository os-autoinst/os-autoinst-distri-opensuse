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

local resize() = {
  drives: [
    {
      search: '/dev/vda',
      partitions: [
        {
          search: '/dev/vda2',
          filesystem: { path: '/' },
          size: '12.5 GiB',
        },
        {
          search: '/dev/vda3',
          filesystem: { path: 'swap' },
          size: '1 GiB',
        },
        {
          filesystem: { path: '/home' },
          encryption: {
            luks2: { password: 'nots3cr3t' },
          },
        },
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

local mdroot_partition = {
  alias: 'mdroot',
  id: 'raid',
  size: '7.81 GiB',
};

local mdswap_partition = {
  alias: 'mdswap',
  id: 'raid',
  size: '512 MiB',
};

local raid(level='raid0', boot_type='bios') = {
  drives: if boot_type == 'uefi' then [
    // First disk: mount EFI
    {
      partitions: [
        { delete: true, search: '*' },
        {
          id: 'esp',
          size: '128 MiB',
          filesystem: { path: '/boot/efi', type: 'vfat' },
        },
        mdroot_partition,
        mdswap_partition,
      ],
    },
    // Additional disks: EFI partition, not mounted
    {
      search: '*',
      partitions: [
        { delete: true, search: '*' },
        {
          id: 'esp',
          size: '128 MiB',
          filesystem: { type: 'vfat' },
        },
        mdroot_partition,
        mdswap_partition,
      ],
    },
  ] else if boot_type == 'prep' then [
    // PowerPC PReP boot partition case
    {
      search: '*',
      partitions: [
        { delete: true, search: '*' },
        { id: 'prep', size: '8 MiB' },
        mdroot_partition,
        mdswap_partition,
      ],
    },
  ] else [
    // Legacy BIOS (non-UEFI) case
    {
      search: '*',
      partitions: [
        { delete: true, search: '*' },
        { id: 'bios_boot', size: '8 MiB' },
        mdroot_partition,
        mdswap_partition,
      ],
    },
  ],
  mdRaids: [
    {
      devices: [
        'mdroot',
      ],
      level: level,
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
{
  lvm: lvm(false),
  lvm_encrypted: lvm(true),
  lvm_tpm_fde: lvm(true, 'tpmFde'),
  raid0: raid('raid0'),
  raid0_uefi: raid('raid0', 'uefi'),
  raid0_prep: raid('raid0', 'prep'),
  raid1: raid('raid1'),
  raid1_uefi: raid('raid1', 'uefi'),
  raid5: raid('raid5'),
  raid5_uefi: raid('raid5', 'uefi'),
  raid6: raid('raid6'),
  raid6_uefi: raid('raid6', 'uefi'),
  raid10: raid('raid10'),
  raid10_uefi: raid('raid10', 'uefi'),
  resize: resize(),
  root_filesystem_ext4: root_filesystem('ext4'),
  root_filesystem_xfs: root_filesystem('xfs'),
  whole_disk_and_boot_unattended: whole_disk_and_boot_unattended(),
}
