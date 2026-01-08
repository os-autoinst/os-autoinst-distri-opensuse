# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the product installed is SLES via /etc/os-release
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use testapi;
use Config::Tiny;
use Test::Assert ':all';

sub run {
    select_console 'root-console';

    my $os_release_output = script_output('cat /etc/os-release');
    my $os_release_name = Config::Tiny->read_string($os_release_output)->{_}->{NAME};
    assert_equals('"SLES"', $os_release_name, 'Wrong product NAME in /etc/os-release');
}

1;
