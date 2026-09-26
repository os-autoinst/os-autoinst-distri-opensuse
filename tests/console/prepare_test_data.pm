# SUSE's openQA tests
#
# Copyright 2012-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: prepare test data
# - As user, get test data from local autoinst service as cpio archive
# - Extract the cpio archive in place
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_public_cloud';

sub run {
    select_serial_terminal;
    ensure_serialdev_permissions;

    my $timeout = get_var('PREPARE_TEST_DATA_TIMEOUT', 300);

    select_console 'user-console';
    assert_script_run "curl -L -sS -f " . autoinst_url('/data') . " | cpio -id", timeout => $timeout;
}

sub test_flags {
    return is_public_cloud() ? {milestone => 0, fatal => 1, no_rollback => 1} : {milestone => 1, fatal => 1};
}

1;
