# SUSE's openQA tests
#
# Copyright (c) 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check logs to find error and upload all needed logs
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster qw(get_cluster_name ha_export_logs);

sub run {
    my $cluster_name = get_cluster_name;

    # Checking cluster state can take time, so default timeout is not enough
    assert_script_run 'crm script run health', 240;

    barrier_wait("LOGS_CHECKED_$cluster_name");

    # Export logs
    ha_export_logs;

    # Looking for segfault during the test
    record_soft_failure "bsc#1132123" if (script_run '(( $(grep -sR segfault /var/log | wc -l) == 0 ))');
}

# Specific test_flags for this test module
sub test_flags {
    return {milestone => 1};
}

1;
