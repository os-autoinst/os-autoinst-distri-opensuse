{
  bootloader(bootloader, bootloader_timeout, bootloader_extra_kernel_params):: {
    [if bootloader || bootloader_timeout != '' || bootloader_extra_kernel_params != '' then 'bootloader']: std.prune({
      [if bootloader then 'stopOnBootMenu']: true,
      [if bootloader_timeout then 'timeout']: 15,
      [if bootloader_extra_kernel_params != '' then 'extraKernelParams']: bootloader_extra_kernel_params,
    }),
  },
  files: [{
     destination: '/usr/local/share/dummy.xml',
     url: 'dummy.xml'
  }],
  localization: {
    language: 'cs_CZ.UTF-8',
    keyboard: 'cz',
  },
  user: {
    fullName: 'Bernhard M. Wiedemann',
    password: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    hashedPassword: true,
    userName: 'bernhard'
  },
  root(params):: {
    [if params.worker then 'password']: std.get(params, "password", default='$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/'),
    [if params.password == '' then 'hashedPassword']: true,
    sshPublicKey: std.get(params, "ssh_key", default="fake public key to enable sshd and open firewall"),
  },
}
