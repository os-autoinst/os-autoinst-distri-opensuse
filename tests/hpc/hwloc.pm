# SUSE's hwloc tests
#
# Copyright 2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Run testsuite included in hwloc sources
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils;

sub run() {
    # install hwloc testsuite
    select_console 'root-console';
    if (check_var('VERSION', '12-SP2')) {
        zypper_call('ar http://download.suse.de/ibs/QA:/SLE12SP2/update/ hwloc-testrepo');
    }

    elsif (check_var('VERSION', '12-SP3')) {
        zypper_call('ar http://download.suse.de/ibs/QA:/SLE12SP3/update/ hwloc-testrepo');
    }
    else {
        my $version = get_var('VERSION');
        my $distri = get_var('DISTRI');
        die "hwloc testsuite tests not supported for $distri version $version";
    }
    #according to PM, the HPC devel repo will be valid for SLE12SP2 and later service packs
    zypper_call('ar http://download.suse.de/ibs/Devel:/HPC:/SLE12SP2/standard/ HPC-module-hwloc');

    zypper_call('--gpg-auto-import-keys ref');
    zypper_call('in hwloc hwloc-testsuite');

    # run the testsuite test scripts
    assert_script_run('cd /var/opt/hwloc-tests; ./run-tests.sh 2>&1 | tee /tmp/testsuite.log');

    my $error = script_run("sed -n '/ERROR/s/# [[:graph:]]* *//p' /tmp/testsuite.log");
    my $fail = script_run("sed -n '/FAIL/s/# [[:graph:]]* *//p' /tmp/testsuite.log");
    if ($error != 0 || $fail != 0) {
        assert_script_run('cp /tmp/testsuite.log /var/opt/hwloc-tests/logs; tar cjf hwloc-testsuite-logs.tar.bz2 logs');
        upload_logs('hwloc-testsuite-logs.tar.bz2');
    }

    assert_screen('hwloc-testsuite-result');

    #cleanup
    zypper_call('rm hwloc hwloc-testsuite');
    zypper_call('rr hwloc-testrepo HPC-module-hwloc');
}

1;
