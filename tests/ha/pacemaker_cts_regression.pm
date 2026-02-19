# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: pacemaker-cts
# Summary: Execute regression tests with pacemaker-cts
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'haclusterbasetest';
use testapi;
use Utils::Architectures;
use utils 'zypper_call';
use hacluster;

sub run {
    my $cts_path = '/usr/share/pacemaker/tests';
    my @tests_to_run = qw(cts-cli cts-exec cts-scheduler cts-fencing);
    my $log = '/tmp/cts_regression.log';
    my $timeout = 600;

    # pacemaker-cts requires hostname to be solvable. Let's make sure
    # this happens in our test by adding an entry in /etc/hosts if
    # SUT fails to resolve its own name
    if (script_run('host $(hostnamectl hostname)')) {
        my $ip = get_my_ip();
        assert_script_run "echo $ip    \$(hostnamectl hostname) >> /etc/hosts";
    }

    # Some of the tests take longer to complete in aarch64.
    # This increases the timeout in that ARCH
    $timeout *= 2 if is_aarch64;

    zypper_call 'in pacemaker-cts';

    foreach my $cts_tests (@tests_to_run) {
        record_info("$cts_tests", "Starting $cts_tests");
        assert_script_run "$cts_path/$cts_tests -V | tee -a $log 2>&1", timeout => $timeout;
        save_screenshot;
    }

    upload_logs $log;
}

1;
