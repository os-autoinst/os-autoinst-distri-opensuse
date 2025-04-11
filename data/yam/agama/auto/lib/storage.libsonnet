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

local resize(rootsize='') = {
  drives: [
    {
      "search": "/dev/vda",
      "partitions": [
        {
          "search": "/dev/vda2",
          "filesystem": { "path": "/" },
          "size": {
            "min": rootsize,
            "max": "current"
          }
        },
        {
          "search": "/dev/vda3",
          "filesystem": { "path": "swap" },
          "size": "1 GiB"
        },
        {
          "filesystem": { "path": "/home" },
          "encryption": {
            "luks2": { "password": "nots3cr3t" }
          }
        },
      ],
    },
  ],
};

local lvm(encrypted=false) = {
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
};

{
  lvm: lvm(false),
  lvm_encrypted: lvm(true),
  resize_2g: resize('2 GiB'),
  root_filesystem_ext4: root_filesystem('ext4'),
  root_filesystem_xfs: root_filesystem('xfs'),
}
