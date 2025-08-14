# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: crmsh
# Summary: Check logs to find error and upload all needed logs
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.com>

use base 'opensusebasetest';
use testapi;
use lockapi;
use hacluster qw(get_cluster_name ha_export_logs);
use version_utils 'is_sle';
use Utils::Logging qw(record_avc_selinux_alerts);

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
    if (script_run '(( $(grep -E -sR iscsiadm.+segfault /var/log | wc -l) == 0 ))') {
        record_soft_failure "bsc#1181052 - segfault on iscsiadm";
    } else {
        validate_script_output(
            'grep -sR --before-context=5 --after-context=15 segfault /var/log || echo "There is no SEGFAULT in the logs."',
            # there must be _no_ segfault
            sub { /segfault/ ? 0 : 1 },
            title => 'segfault?'
        );
    }
}

sub post_run_hook {
    shift->record_avc_selinux_alerts() if is_sle('16+');
}

# Specific test_flags for this test module
sub test_flags {
    return {milestone => 1};
}

1;
