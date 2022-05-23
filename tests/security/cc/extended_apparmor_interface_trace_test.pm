# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run 'Extended AppArmor interface trace test' test case of ATSec test suite
# Maintainer: xiaojing.liu <xiaojing.liu@suse.com>
# Tags: poo#111242

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test;

sub run {
    my ($self) = shift;

    select_console 'root-console';

    zypper_call('in strace');

    assert_script_run("cd $audit_test::test_dir/audit-test/kvm_svirt_apparmor/tests");

    # Clean up the previous test logs
    script_run('rm -rf /tmp/vm-sep/');

    # Record kernel parameters during boot
    record_info('Kernel parameters during boot', script_output('cat /proc/cmdline'));

    # Modify the test code
    my $test_file = 'vm-sep';
    my $strace_log = 'strace.log';
    assert_script_run("sed -i 's/\\/sbin\\/apparmor_parser -a \$C_LABEL/strace -o $strace_log &/' $test_file");

    # Run the test script with strace
    script_run("./$test_file", timeout => 120);

    # Check if the strace log is generated
    assert_script_run("test -e $strace_log");

    if (script_run("grep '\\.load' $strace_log") != 0) {
        record_info('The strace log did not show the expected interface usage');
    }

    # Run the test script with strace -tt -ff
    assert_script_run("sed -i 's/strace -o/strace -tt -ff -o/' $test_file");

    # Run the test script with strace -ff
    script_run("./$test_file", timeout => 120);

    # Check if the strace logs with pid are generated
    assert_script_run('find . -name "strace.log.*"');

    # Use -ff option to ensure that strace also follows children,
    # so the strace log show the expected interface usage
    assert_script_run("strace-log-merge $strace_log | grep '\\.load'");
}

1;
