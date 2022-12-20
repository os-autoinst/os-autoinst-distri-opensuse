# SUSE's openssh fips tests
#
# Copyright 2016 - 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openssh expect
#
# Summary: FIPS: openssh
#          Involve the existing openssh test case: sshd.pm
#          Create new case ssh_pubkey.pm to test public key
#          Create new case openssh_fips.pm to verify that
#          openssh will refuse to work with any non-approved
#          algorithm in fips mode, just like blowfish cipher
#          or MD5 hash.
#
# Maintainer: QE Security <none@suse.de>
# Tags: tc#1525228, poo#90458

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use version_utils qw(is_sle);

sub run {
    select_serial_terminal;

    zypper_call('info openssh');
    my $current_ver = script_output("rpm -q --qf '%{version}\n' openssh");

    # openssh update to 8.3 in SLE15 SP3
    if (!is_sle('<15-sp3') && ($current_ver ge 8.3)) {
        record_info("openssh version", "Current openssh package version: $current_ver");
    }
    else {
        record_soft_failure("jsc#SLE-16308: openssh version outdate, openssh version need to be updated over to 8.3+ in SLE15 SP3");
    }

    zypper_call('in expect') if script_run('rpm -q expect');
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
    validate_script_output 'ssh-keygen -t dsa -f ~/.ssh/id_dsa -P "" 2>&1 || true', sub { m/Key type dsa not allowed in FIPS mode/ };

    # Although there is StrictHostKeyChecking=no option, but the fingerprint
    # for localhost was still added into ~/.ssh/known_hosts, which potentially
    # lead to other cases failed. So remove it.
    assert_script_run "rm -r ~/.ssh/";
}

1;
