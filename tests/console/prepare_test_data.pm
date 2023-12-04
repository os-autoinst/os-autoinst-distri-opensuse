# SUSE's openQA tests
#
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: prepare test data
# - As user, get "test.data" from local autoinst service
# - Run "cpio -id < test.data"
# - Delete the downloaded CPIO archive again
# - Run "ls -al data"
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base "consoletest";
use testapi;
use utils;
use Utils::Backends;
use strict;
use warnings;

sub run {
    is_ipmi ? use_ssh_serial_console : select_console 'root-console';
    ensure_serialdev_permissions;

    my $timeout = get_var('PREPARE_TEST_DATA_TIMEOUT', 300);

    select_console 'user-console';
    assert_script_run "curl -L -v -f " . autoinst_url('/data') . " | cpio -id", timeout => $timeout;
    script_run "ls -al data";
}

sub test_flags {
    return get_var('PUBLIC_CLOUD') ? {milestone => 0, fatal => 1, no_rollback => 1} : {milestone => 1, fatal => 1};
}

1;
