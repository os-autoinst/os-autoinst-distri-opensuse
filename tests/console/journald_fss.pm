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
use utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # Enable FSS (Forward Secure Sealing)
    assert_script_run("sed -i -e 's/^Storage/#Storage/g' -e 's/^Seal/#Seal/g' /etc/systemd/journald.conf");
    assert_script_run('echo -e "Storage=persistence\nSeal=yes" >> /etc/systemd/journald.conf');
    assert_script_run("mkdir -p /var/log/journal");
    systemctl 'restart systemd-journald.service';

    # Setup keys
    assert_script_run("journalctl --interval=30s --setup-keys | tee /tmp/key");
    assert_script_run("journalctl --rotate");

    # Verify the journal with valid verification key
    assert_script_run('key=$(cat /tmp/key); echo "Verify with key: $key"; journalctl --verify --verify-key=$key');

    # Wait some time for the secret key being changed, and verify again
    assert_script_run('sleep 40; key=$(cat /tmp/key); echo "Verify with key: $key"; journalctl --verify --verify-key=$key', 60);

    assert_script_run("rm -f /tmp/key");
}

sub test_flags {
    return {fatal => 0};
}
1;
