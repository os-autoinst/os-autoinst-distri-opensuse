# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh
# Summary: Check logs to find error and upload all needed logs
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

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
    if (script_run("crm script run health", bmwqemu::scale_timeout(240)) != 0) {
        record_soft_failure("bsc#1180618, unexpected hostname in the output");
    }

    barrier_wait("LOGS_CHECKED_$cluster_name");

    # Export logs
    ha_export_logs;

    # Looking for segfault during the test
    if (script_run '(( $(grep -sR segfault /var/log | wc -l) == 0 ))') {
        if (script_run '(( $(grep -E -sR iscsiadm.+segfault /var/log | wc -l) == 0 ))') {
            record_soft_failure "bsc#1181052 - segfault on iscsiadm";
        }
        else {
            die "segfault detected in the system! Aborting";
        }
    }
}

# Specific test_flags for this test module
sub test_flags {
    return {milestone => 1};
}

1;
