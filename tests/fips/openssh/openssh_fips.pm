# SUSE's openssh fips tests
#
# Copyright 2024 SUSE LLC
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
use version_utils qw(is_sle is_transactional is_sle_micro);

sub is_older_product {
    return 1 if is_sle('<16');
    return 1 if is_sle_micro('<6.2');
    return 0;    # default for Tumbleweed and newer SLE Micro
}

sub run {
    select_serial_terminal;

    zypper_call('info openssh');
    my $current_ver = script_output("rpm -q --qf '%{version}\n' openssh");
    record_info("openssh version", "Current openssh package version: $current_ver");

    # this package is not available on SL Micro
    zypper_call('in expect') unless is_transactional;

    # on Tumbleweed sshd is not active by default:
    # ensure sshd is installed and started before trying to connect
    my $pkg_name = is_sle('<=15-SP2') ? "openssh" : "openssh-server";
    assert_script_run "rpm -q " . $pkg_name . " || zypper in -y " . $pkg_name;
    assert_script_run 'systemctl is-active sshd || systemctl enable --now sshd';

    # on SL Micro we skip this check because it behaves differently
    validate_script_output
      'expect -c "spawn ssh -v -o StrictHostKeyChecking=no localhost; expect -re \[Pp\]assword; send badpass\n; exit 0"',
      sub { m/MD5 not allowed in FIPS 140-2 mode, using SHA|Server host key: .* SHA/ } unless is_transactional;

    # Verify ssh doesn't work with non-approved cipher in fips mode
    my $cmd = is_sle_micro('>=6.0') ? 'ssh -v -c blowfish localhost' : 'expect -c "spawn ssh -v -c blowfish localhost; expect EOF; exit 0"';
    validate_script_output("$cmd", sub { m/Unknown cipher type|no matching cipher found/ }, proceed_on_failure => 1);

    # Verify ssh doesn't work with non-approved hash in fips mode
    $cmd = is_sle_micro('>=6.0') ? 'ssh -v -c aes256-ctr -m hmac-md5 localhost' : 'expect -c "spawn ssh -v -c aes256-ctr -m hmac-md5 localhost; expect EOF; exit 0"';
    validate_script_output("$cmd", sub { m/Unknown mac type|no matching MAC found/ }, proceed_on_failure => 1);

    # Verify ssh doesn't support DSA public key in fips mode
    # exact message depends on the product version
    my $message = is_older_product ? "Key type dsa not alowed in FIPS mode" : "unknown key type dsa";
    validate_script_output('ssh-keygen -t dsa -f ~/.ssh/id_dsa -P "" 2>&1 || true', sub { m/$message/ }, proceed_on_failure => 1);

    # Although there is StrictHostKeyChecking=no option, but the fingerprint
    # for localhost was still added into ~/.ssh/known_hosts, which potentially
    # lead to other cases failed. So remove it.
    assert_script_run "rm -r ~/.ssh/";
}

1;
