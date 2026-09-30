# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Prevent SUT de-registration from SCC by sending keepalive
# Maintainer: Wang Jun <jgwang@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils qw(script_retry);
use version_utils qw(is_sle is_sles4sap);
use serial_terminal qw(select_serial_terminal);

sub run {
    my $self = shift;

    my $flavor = get_var('FLAVOR') // '';
    unless (is_sle('>=16.0') && (is_sles4sap() || $flavor =~ /-(SAP|HA)-/i)) {
        record_info('Keepalive Skip', 'SUSEConnect keepalive is only triggered on SLES 16.0 HA/SAP tests');
        return;
    }

    select_serial_terminal;
    if (script_run('which SUSEConnect') == 0) {
        # Retry to address transient network jitter or SCC response latency
        my $exit_code = script_retry(
            'bash -c "sleep $((RANDOM % 20)); SUSEConnect --keepalive"',
            retry => 3,
            delay => 5,
            timeout => 120,
            die => 0
        );
        if ($exit_code != 0) {
            # Collect diagnostic information before dying
            record_info('Registration Status', script_output('SUSEConnect --status-text', proceed_on_failure => 1));
            record_info('SCC Connectivity', script_output('curl -Iv -m 10 https://scc.suse.com 2>&1 || true', proceed_on_failure => 1));
            die "SUSEConnect --keepalive returned exit code: $exit_code. System might not be registered or SCC is unreachable.";
        }
        else {
            record_info('SCC Info', 'Successfully executed SUSEConnect --keepalive.');
        }
    }
    else {
        record_info('SCC Info', 'SUSEConnect command is not available. Skipping keepalive.', result => 'info');
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
