# SUSE's openQA tests
#
# Copyright 2016-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Case 1560070  - FIPS: systemd journald FSS
#
# Package: systemd/journald_fss
# Summary: Add Case 1463314-FIPS:systemd-journald test
#          Systemd depend on libgcrypt for journald's FSS(Forward Secure Sealing) function
#          It is only needed to test journald's key generation and verification function
#          Verify key should be generated,as well as a QR code
#          No failed messages output
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#102038, poo#107485

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_leap is_sle is_tumbleweed);
use utils;

sub run {
    select_serial_terminal;

    # Enable FSS (Forward Secure Sealing)
    my $path = (is_sle('>=15-SP6') || is_leap('>=15.6') || is_tumbleweed) ? "/etc/systemd/journald.conf.d" : "/etc/systemd";
    my $journald_conf = "$path/journald.conf";

    assert_script_run("sed -i -e 's/^Storage/#Storage/g' -e 's/^Seal/#Seal/g' $journald_conf") if is_sle('<=15-SP5') || is_leap('<=15.5');
    assert_script_run("echo -e \"Storage=persistent\nSeal=yes\" >> $journald_conf");
    assert_script_run("mkdir -p /var/log/journal");
    systemctl 'restart systemd-journald.service';

    # Setup keys
    assert_script_run("journalctl --flush");
    assert_script_run("journalctl --interval=30s --setup-keys | tee /tmp/key");
    assert_script_run("journalctl --rotate");

    # Verify the journal with valid verification key
    verify_journal_with_key("/tmp/key");

    # Wait some time for the secret key being changed, and verify again
    assert_script_run('sleep 40');
    verify_journal_with_key("/tmp/key", 60);

    assert_script_run("rm -f /tmp/key");
}

sub verify_journal_with_key {
    my ($key_file, $timeout) = @_;
    my $key = script_output("cat $key_file");
    assert_script_run("echo \"Verify with key: $key\"; journalctl --verify --verify-key=$key", $timeout);
}

sub test_flags {
    return {fatal => 0};
}
1;
