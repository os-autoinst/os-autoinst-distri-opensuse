# SUSE's openjdk fips tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: prepare env for openjdk tests
# Maintainer: QE Security <none@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use openjdktest;

sub run {
    my $self = @_;
    my $interactive_str = [
        {
            prompt => qr/Enter new password/m,
            key => 'ret',
        },
        {
            prompt => qr/Re-enter password/m,
            key => 'ret',
        },
    ];

    select_console "root-console";
    zypper_call("in mozilla-nss-tools git-core");

    if (script_run("test -d /etc/pki/nssdb") != 0) {
        assert_script_run("mkdir /etc/pki/nssdb");
        script_run_interactive("certutil -d /etc/pki/nssdb -N", $interactive_str, 30);
    }
}

sub test_flags {
    return {no_rollback => 1};
}

1;

