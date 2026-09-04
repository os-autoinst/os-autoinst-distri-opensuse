# SUSE's openjdk fips tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: prepare env for openjdk tests
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils;
use openjdktest;
use serial_terminal qw(select_serial_terminal);

sub run {
    my $self = @_;
    select_serial_terminal;
    zypper_call("in mozilla-nss-tools git-core");

    if (script_run("test -d /etc/pki/nssdb") != 0) {
        assert_script_run("mkdir /etc/pki/nssdb");
        assert_script_run("certutil -d /etc/pki/nssdb -N --empty-password");
    }
}

sub test_flags {
    return {no_rollback => 1};
}

1;

