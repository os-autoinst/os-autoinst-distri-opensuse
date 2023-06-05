# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate that the product installed by agama via /etc/os-release
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use Config::Tiny;
use Test::Assert ':all';
use scheduler 'get_test_suite_data';

sub run {
    select_console 'root-console';

    my $os_release_name_expected = get_test_suite_data()->{os_release_name};

    my $os_release_output = script_output('cat /etc/os-release');
    my $os_release_name = Config::Tiny->read_string($os_release_output)->{_}->{NAME};

    assert_equals("\"" . $os_release_name_expected . "\"", $os_release_name, 'Wrong product NAME in /etc/os-release');
}

1;
