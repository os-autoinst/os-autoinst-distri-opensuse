# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'stig' hardening in the 'scap-security-guide': mitigation mode
# Maintainer: QE Security <none@suse.de>
# Tags: poo#93886, poo#104943

use base 'stigtest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;

    # Get ds file and profile ID, etc.
    my $f_ssg_ds = is_sle ? $stigtest::f_ssg_sle_ds : $stigtest::f_ssg_tw_ds;
    my $profile_ID = is_sle ? $stigtest::profile_ID_sle : $stigtest::profile_ID_tw;
    my $f_stdout = $stigtest::f_stdout;
    my $f_stderr = $stigtest::f_stderr;
    my $f_report = $stigtest::f_report;

    select_console 'root-console';

    # Verify mitigation mode
    my $ret = script_run("oscap xccdf eval --profile $profile_ID --remediate --oval-results --report $f_report $f_ssg_ds > $f_stdout 2> $f_stderr", timeout => 600);
    record_info("Return=$ret", "# oscap xccdf eval --profile $profile_ID --remediate\" returns: $ret");
    if ($ret) {
        $self->result('fail');
        record_info('bsc#1194676', 'remediation should be succeeded');
    }

    # Upload logs & ouputs for reference
    $self->upload_logs_reports();
}

sub test_flags {
    # Do not rollback as next test module will be run on this test environments
    return {milestone => 1, always_rollback => 0};
}

1;
