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

{
  lvm(encrypted=false): {
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
                luks2: { password: "nots3cr3t" }
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
  },
  root_filesystem_ext4: root_filesystem('ext4'),
  root_filesystem_xfs: root_filesystem('xfs'),
}
