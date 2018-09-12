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
use testapi;
use lockapi;
use hacluster;
use utils 'systemctl';

sub run {
    my $cluster_name = get_cluster_name;
    my $hawk_port    = '7630';

    barrier_wait("HAWK_INIT_$cluster_name");

    # Test the Hawk service
    systemctl 'show -p ActiveState hawk.service | grep ActiveState=active';

    # Test the Hawk port
    assert_script_run "ss -nap | grep '.*LISTEN.*:$hawk_port\[[:blank:]]*'";

    # Test Hawk connection
    assert_script_run "nc -zv localhost $hawk_port";

    barrier_wait("HAWK_CHECKED_$cluster_name");
}

# Specific test_flags for this test module
sub test_flags {
    return {milestone => 1};
}

1;
