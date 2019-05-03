# SUSE's openQA tests
#
# Copyright (c) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Execute regression tests with pacemaker-cts
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use hacluster;

sub run {
    my $cts_path     = '/usr/share/pacemaker/tests';
    my @tests_to_run = qw(cts-cli cts-exec cts-scheduler cts-fencing);
    my $log          = '/tmp/cts_regression.log';
    my $timeout      = 600;

    # Some of the tests take longer to complete in aarch64.
    # This increases the timeout in that ARCH
    $timeout *= 2 if check_var('ARCH', 'aarch64');

    zypper_call 'in pacemaker-cts';

    foreach my $cts_tests (@tests_to_run) {
        record_info("$cts_tests", "Starting $cts_tests");
        assert_script_run "$cts_path/$cts_tests -V | tee -a $log 2>&1", timeout => $timeout;
        save_screenshot;
    }

    upload_logs $log;
}

1;
