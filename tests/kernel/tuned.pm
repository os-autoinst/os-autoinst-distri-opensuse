# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: tuned
# Summary: Regression test for tuned daemon
# Maintainer: Petr Cervinka <pcervinka@suse.com>
# Tags: https://jira.suse.com/browse/SLE-6514

use base 'consoletest';
use strict;
use warnings;
use testapi;
use Utils::Backends;
use utils;
use version_utils qw(is_sle is_tumbleweed);

sub tuned_set_profile {
    my $tuned_profile = shift;
    assert_script_run "tuned-adm profile $tuned_profile";
    validate_script_output 'tuned-adm active', sub { m/${tuned_profile}/ };
}

sub run {
    my $self = shift;
    my $tuned_log = '/var/log/tuned/tuned.log';
    # Already known errors with bug reference
    my %known_errors;
    $known_errors{bsc_1148789} = 'Executing cpupower error: Error setting perf-bias value on CPU' if is_sle '<15';
    $known_errors{bsc_1148789} = 'Failed to set energy_perf_bias on cpu' if (is_sle('>=15') || is_tumbleweed);

    $self->select_serial_terminal;
    # Install tuned package
    zypper_call 'in tuned';
    # Start daemon
    systemctl 'start tuned';
    # Check status
    systemctl 'status tuned';
    # Set virtual-guest profile for QEMU backends and throughput-performance for the rest
    tuned_set_profile(is_qemu ? 'virtual-guest' : 'throughput-performance');
    # Stop tuned daemon
    systemctl 'stop tuned';
    # Delete and ignore logs from first run without proper profile set
    assert_script_run "rm ${tuned_log}";
    # Start daemon
    systemctl 'start tuned';
    # Check tuned log for errors
    foreach my $error (split(/\n/, script_output "awk '/ERROR/ {\$1=\$2=\"\"; print \$0}' ${tuned_log} | uniq")) {
        for (keys %known_errors) {
            if ($error =~ /${known_errors{$_}}/) {
                my $bugref = $_ =~ s/_/\#/r;
                record_info('Softfail', "$bugref - ${known_errors{$_}}", result => 'softfail');
                last;
            }
            record_info 'unknown error', $error, result => 'fail';
            $self->result('fail');
        }
    }
}

sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    upload_logs '/var/log/tuned/tuned.log';
}
1;
