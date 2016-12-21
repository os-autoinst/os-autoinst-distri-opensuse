# SUSE's openssh fips tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: FIPS: openssh
#    Involve the existing openssh test case: sshd.pm
#
#    Create new case ssh_pubkey.pm to test public key
#
#    Create new case openssh_fips.pm to verify that
#    openssh will refuse to work with any non-approved
#    algorithm in fips mode, just like blowfish cipher
#    or MD5 hash.
# Maintainer: Qingming Su <qingming.su@suse.com>
# Tags: tc#1525228

use base "consoletest";
use strict;
use testapi;

sub run {
    select_console 'root-console';

    # Verify MD5 is disabled in fips mode, no need to login
    validate_script_output
      'expect -c "spawn ssh -v -o StrictHostKeyChecking=no localhost; expect -re \[Pp\]assword; send badpass\n; exit 0"',
      sub { m/MD5 not allowed in FIPS 140-2 mode, using SHA|Server host key: .* SHA/ };

    # Verify ssh doesn't work with non-approved cipher in fips mode
    validate_script_output 'expect -c "spawn ssh -v -c blowfish localhost; expect EOF; exit 0"', sub { m/Unknown cipher type|no matching cipher found/ };

    # Verify ssh doesn't work with non-approved hash in fips mode
    validate_script_output 'expect -c "spawn ssh -v -c aes256-ctr -m hmac-md5 localhost; expect EOF; exit 0"',
      sub { m/Unknown mac type|no matching MAC found/ };

    # Verify ssh doesn't support DSA public key in fips mode
    validate_script_output 'ssh-keygen -t dsa -f ~/.ssh/id_dsa -P "" 2>&1 || true', sub { m/Key type dsa not alowed in FIPS mode/ };
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
