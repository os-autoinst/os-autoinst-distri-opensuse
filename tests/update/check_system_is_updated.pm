# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: PackageKit
# Summary: Check that no updates are available after they were previously applied
# - execute pkcon get-updates and check that the message says 'there are no updates'
# Maintainer: mkravec <mkravec@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'ensure_serialdev_permissions';

sub run {
    select_console 'root-console';
    ensure_serialdev_permissions;
    # pkcon returns non-zero code (5 'Nothing useful was done.')
    # so don't validate exit code and just match
    script_run "pkcon get-updates | tee /dev/$serialdev", 0;
    die "pkcon get-updates seems to contain updates, whereas was just updated" unless wait_serial('There are no updates');
}

sub test_flags {
    return {fatal => 1};
}

1;
