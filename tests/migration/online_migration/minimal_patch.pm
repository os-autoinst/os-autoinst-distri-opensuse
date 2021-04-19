# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: zypper
# Summary: sle12 online migration testsuite
# Maintainer: yutao <yuwang@suse.com>

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
    remove_ltss;
}

sub test_flags {
    return {fatal => 1};
}

1;
