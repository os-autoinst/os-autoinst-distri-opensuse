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
{
  lvm: lvm(false),
  lvm_encrypted: lvm(true),
  lvm_tpm_fde: lvm(true, 'tpmFde'),
  root_filesystem_ext4: root_filesystem('ext4'),
  root_filesystem_xfs: root_filesystem('xfs'),
  whole_disk_and_boot_unattended: whole_disk_and_boot_unattended(),
}
