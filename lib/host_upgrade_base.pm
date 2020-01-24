# SUSE's openQA tests
#
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
package host_upgrade_base;
# Summary: host_upgrade_base: Geting prefix part of command line for running case host upgrade project.
# Maintainer: alice <xlai@suse.com>

use strict;
use warnings;
use base "virt_autotest_base";
use testapi;

sub get_test_name_prefix {
    my $test_name_prefix = "";

    my $mode       = get_var("TEST_MODE",       "");
    my $hypervisor = get_var("HOST_HYPERVISOR", "");
    my $base       = get_var("BASE_PRODUCT",    "");    #EXAMPLE, sles-11-sp3
    my $upgrade    = get_var("UPGRADE_PRODUCT", "");    #EXAMPLE, sles-12-sp2

    $base    =~ s/-//g;
    $upgrade =~ s/-//g;

    $test_name_prefix = "/usr/share/qa/tools/test-VH-Upgrade-$mode-$hypervisor-$base-$upgrade";

    return "$test_name_prefix";
}

1;

