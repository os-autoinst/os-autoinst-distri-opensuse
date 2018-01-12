# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check logs to find error and upload all needed logs
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use strict;
use testapi;
use lockapi;
use hacluster;

sub run {
    barrier_wait("FENCING_DONE_$cluster_name");

    # Do some extra verification and export logs
    assert_script_run '(( $(grep -sR segfault /var/log | wc -l) == 0 ))';
    record_soft_failure 'bsc#1071519' if (script_run 'crm script run health');
    ha_export_logs;

    barrier_wait("LOGS_CHECKED_$cluster_name");
}

# Specific test_flags for this test module
sub test_flags {
    return {milestone => 1};
}

1;
# vim: set sw=4 et:
