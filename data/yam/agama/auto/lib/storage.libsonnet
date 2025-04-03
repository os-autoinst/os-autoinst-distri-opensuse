local root_filesystem(filesystem) = {
  drives: [
    {
      partitions: [
        { search: "*", delete: true },
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
        { search: "*", delete: true }
      ]
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
              [encryption]: { password: "nots3cr3t" }
            }
          },
          [if encrypted == false then 'generate']: ['pvs-disk'],
        },
      ],
      logicalVolumes: [
        { generate: 'default' },
      ],
    },
  ]
};

{
  lvm: lvm(false),
  lvm_encrypted: lvm(true),
  lvm_tpm_fde: lvm(true, 'tpmFde'),
  root_filesystem_ext4: root_filesystem('ext4'),
  root_filesystem_xfs: root_filesystem('xfs'),
}
