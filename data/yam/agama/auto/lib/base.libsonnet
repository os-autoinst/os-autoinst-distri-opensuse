{
  bootloader: {
    stopOnBootMenu: true
  },
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
  root(password):: {
    [if password then 'password']: '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/',
    [if password then 'hashedPassword']: true,
    sshPublicKey: 'fake public key to enable sshd and open firewall',
  },
}
