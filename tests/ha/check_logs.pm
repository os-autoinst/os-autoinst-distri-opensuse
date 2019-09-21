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
use version_utils 'is_sle';

sub run {
    my $cluster_name = get_cluster_name;

    # Checking cluster state can take time, so default timeout is not enough
    if (check_var('ARCH', 's390x') and is_sle('12-sp5+')) {
        # 'crm script run health' is currently failing in SLES+HA 12-SP5 and newer on s390x
        record_soft_failure "bsc#1150704 - 'crm script run health' is known to crash the cluster on SLES+HA 12-SP5+ on s390x";
    }
    else {
        assert_script_run 'crm script run health', 240 * get_var('TIMEOUT_SCALE', 1);
    }

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
