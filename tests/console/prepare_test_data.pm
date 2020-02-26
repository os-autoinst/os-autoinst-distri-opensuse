# SUSE's openQA tests
#
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: prepare test data
# - As user, get "test.data" from local autoinst service
# - Run "cpio -id < test.data"
# - Delete the downloaded CPIO archive again
# - Run "ls -al data"
# Maintainer: Zaoliang Luo <zluo@suse.de>

use base "consoletest";
use testapi;
use utils;
use Utils::Backends 'use_ssh_serial_console';
use strict;
use warnings;

sub run {
    check_var("BACKEND", "ipmi") ? use_ssh_serial_console : select_console 'root-console';

    select_console 'user-console';
    assert_script_run "curl -L -v -f " . autoinst_url('/data') . " > test.data", timeout => 300;
    assert_script_run " cpio -id < test.data";
    assert_script_run "rm test.data";
    script_run "ls -al data";
}

sub test_flags {
    return get_var('PUBLIC_CLOUD') ? {milestone => 0, fatal => 1, no_rollback => 1} : {milestone => 1, fatal => 1};
}

1;
