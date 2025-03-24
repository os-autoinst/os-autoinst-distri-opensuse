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

function(storage='', encrypted=false) {
  [if storage == 'lvm' then 'lvm']: {
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
  [if storage == 'root_filesystem_ext4' then 'root_filesystem_ext4']: root_filesystem('ext4'),
  [if storage == 'root_filesystem_xfs' then 'root_filesystem_xfs']: root_filesystem('xfs'),
}
