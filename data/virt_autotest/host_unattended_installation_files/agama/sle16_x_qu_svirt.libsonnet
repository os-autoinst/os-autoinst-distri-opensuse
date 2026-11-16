// Copyright SUSE LLC
// SPDX-License-Identifier: GPL-2.0-or-later
// Shared SLE 16.x QU profile for the current and future QU releases.
local password_hash = '$6$vYbbuJ9WMriFxGHY$gQ7shLw9ZBsRcPgo6/8KmfDvQ/lCqxW8/WnMoLCoWGdHO6Touush1nhegYfdBbXRpsQuy/FTZZeg7gQL50IbA/';

function(product='SLES', mode='standard', registration_code='')
  assert product == 'SLES' : 'The SLE 16 QU profile requires SLES';
  assert mode == 'standard' || mode == 'immutable' : 'Unsupported SLE 16 QU product mode';
  {
    product: {
      id: product,
      mode: mode,
      registrationCode: registration_code,
      registrationUrl: 'https://scc.suse.com',
    },
    bootloader: {
      stopOnBootMenu: true,
    },
    access: {
      ssh: 'enabled',
    },
    root: {
      password: password_hash,
      hashedPassword: true,
    },
    user: {
      fullName: 'Bernhard M. Wiedemann',
      userName: 'bernhard',
      password: password_hash,
      hashedPassword: true,
    },
  }