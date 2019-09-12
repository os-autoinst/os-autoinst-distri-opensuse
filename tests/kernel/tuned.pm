# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Regression test for tuned daemon
# Maintainer: Petr Cervinka <pcervinka@suse.com>
# Tags: https://jira.suse.com/browse/SLE-6514

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;

sub tuned_set_profile {
    my $tuned_profile = shift;
    assert_script_run "tuned-adm profile $tuned_profile";
    validate_script_output 'tuned-adm active', sub { m/${tuned_profile}/ };
}

sub run {
    my $self      = shift;
    my $tuned_log = '/var/log/tuned/tuned.log';
    # Already known errors with bug reference
    my %known_errors = (
        bsc_1148789 => 'Executing cpupower error: Error setting perf-bias value on CPU'
    );
    select_console 'root-console';
    # Install tuned package
    zypper_call 'in tuned';
    # Start daemon
    systemctl 'start tuned';
    # Check status
    systemctl 'status tuned';
    # Set virtual-guest profile for QEMU backends and throughput-performance for the rest
    tuned_set_profile(check_var('BACKEND', 'qemu') ? 'virtual-guest' : 'throughput-performance');
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
                record_soft_failure "$bugref - ${known_errors{$_}}";
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
