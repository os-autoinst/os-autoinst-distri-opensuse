# SLE12 online migration tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: SUSEConnect zypper yast2-registration
# Summary: sle12 online migration testsuite
# Maintainer: yutao <yuwang@suse.com>

use base "y2_module_consoletest";
use strict;
use warnings;
use testapi;
use migration;

sub run {
    select_console 'root-console';
    register_system_in_textmode;
}

sub test_flags {
    return {fatal => 1};
}

1;
