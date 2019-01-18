# SUSE's openQA tests
#
# Copyright (c) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Basic check of Hawk Web interface
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster;
use utils 'systemctl';
use version_utils 'is_sle';

sub run {
    my $cluster_name = get_cluster_name;
    my $hawk_port    = '7630';

    barrier_wait("HAWK_INIT_$cluster_name");

    # Test the Hawk service
    if (!systemctl 'status hawk.service', ignore_failure => 1) {
        # Test if Hawk service state is set to enable
        assert_script_run("systemctl show -p UnitFileState hawk.service | grep UnitFileState=enabled");

        # Test the Hawk port
        assert_script_run "ss -nap | grep '.*LISTEN.*:$hawk_port\[[:blank:]]*'";

        # Test Hawk connection
        assert_script_run "nc -zv localhost $hawk_port";
    }
    else {
        # Hawk is broken in SLE-15-SP1 we have an opened bug, so record it and continue in that case
        if (is_sle('=15-sp1')) {
            record_soft_failure 'Hawk is known to fail in 15-SP1 - bsc#1116209';
        }
        else {
            record_info 'Hawk', 'Hawk is failing! Analysis is requiring and consider to open a bug if needed!';
        }
    }

    # Keep a screenshot for this test
    save_screenshot;

    barrier_wait("HAWK_CHECKED_$cluster_name");
}

# Specific test_flags for this test module
sub test_flags {
    return {milestone => 1};
}

1;
