# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Add sle12 online migration testsuite
#    Fixes follow up by the comments
#
#    Apply fully patch system function
#
#    Fix typo and remove redundant comment
#
#    Remove a unnecessary line
# G-Maintainer: mitiao <mitiao@gmail.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub run() {
    setup_online_migration;
}

1;
# vim: set sw=4 et:
