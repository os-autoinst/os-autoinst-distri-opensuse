local agama = import 'hw.libsonnet';
local findBiggestDisk(disks) =
  local sizedDisks = std.filter(function(d) std.objectHas(d, 'size'), disks);
  local sorted = std.sort(sizedDisks, function(x) x.size);
  sorted[0].logicalname;

{
  description: |||
        Install agama Micro with jsonnet on
        x86_64 and aarch64.
      |||,
  software: {
    product: 'ALP-Micro',
  },
  root: {
    password: 'nots3cr3t',
  },
  user: {
    fullName: 'Jane Doe',
    password: '123456',
    userName: 'jane.doe',
  },
  localization: {
    language: 'en_US',
  },
  storage: {
    devices: [
      {
        name: findBiggestDisk(agama.disks),
      },
    ],
  },
}
