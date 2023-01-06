# SLE12 online migration tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: zypper
# Summary: sle12 online migration testsuite
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use migration;

sub run {
    select_console 'root-console';
    disable_installation_repos;
    minimal_patch_system(version_variable => 'HDDVERSION');
    cleanup_disk_space if get_var('REMOVE_SNAPSHOTS');
    deregister_dropped_modules;
}

sub test_flags {
    return {fatal => 1};
}

1;
