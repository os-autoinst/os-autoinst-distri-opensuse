# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module compiles and runs the glibc testsuite.
# Maintainer: Dario Abatianni <dabatianni@suse.de>


use base "consoletest";
use strict;
use testapi;
use utils;
use version_utils qw(is_opensuse is_sle is_jeos);

sub run
{
    select_console 'root-console';

    if (is_sle('<15'))
    {
        record_info("Skipped", "This test is disabled for <SLE15 at the moment because the test suite is broken.");
        return;
    }

    my $extra_packages;

    # installing systemtap-headers seems to work only for sle 15+, earlier sle versions demand this
    # package too but it doesn't exist in the repository. we keep this in a separate variable here
    # to make it easier to build a coinditional around it when adapting this test to other SLE versions.
    $extra_packages = 'systemtap-headers';

    # make sure all necessary packages needed to run the test suite are installed
    zypper_call "-t in rpmbuild audit-devel libcap-devel libselinux-devel makeinfo gcc-c++ libc++1 libc++-devel libstdc++6 libstdc++-devel libstdc++6-devel-gcc7 libstdc++6-locale glibc-devel-static $extra_packages", dumb_term => 1;

    # install the glibc sources
    zypper_call '-t in -t srcpackage glibc', dumb_term => 1;

    assert_script_run 'cd /usr/src/packages/';

    record_info 'Build glibc', 'Build glibc from sources to get access to the test suite. Expected time: 10 minutes.';
    type_string "rpmbuild -bc SPECS/glibc.spec && echo -e '\nBUILD_SUCCEEDED' > /dev/$serialdev || echo -e '\nBUILD_FAILED' > /dev/$serialdev\n";

    my $build_result = wait_serial(['BUILD_FAILED', 'BUILD_SUCCEEDED'], 3600);
    save_screenshot;

    # extract our marker from the serial output
    $build_result =~ /(^BUILD_[A-Z]+$)/m;

    if ($1 eq 'BUILD_FAILED')
    {
        die 'Building glibc from source failed.';
    }

    if ($1 ne 'BUILD_SUCCEEDED')
    {
        die "Expected BUILD_SUCCEEDED on the serial console, but found $build_result instead.";
    }

    assert_script_run 'cd /usr/src/packages/BUILD/glibc-*/cc-base/';

    record_info 'Test glibc', 'Running glibc test suite. Expected time: 60 minutes';

    my $make_check_log = 'make-check.log';
    type_string "set -o pipefail ; make check 2>&1 | tee $make_check_log && echo -e '\nGLIBC_TEST_SUCCEEDED' > /dev/$serialdev || echo -e '\nGLIBC_TEST_FAILED' > /dev/$serialdev\n";

    my $test_result = wait_serial(['GLIBC_TEST_FAILED', 'GLIBC_TEST_SUCCEEDED'], 7200);
    save_screenshot;

    # extract our marker from the serial output
    $test_result =~ /(^GLIBC_TEST_[A-Z]+$)/m;

    if ($1 eq 'GLIBC_TEST_FAILED')
    {
        record_soft_failure 'Testing glibc failed.';
    }
    elsif ($1 eq 'GLIBC_TEST_SUCCEEDED')
    {
        record_info 'Test passed', 'Testing glibc passed!';
        return;
    }
    else
    {
        die "Expected GLIBC_TEST_SUCCEEDED or GLIBC_TEST_FAILED on the serial console, but found $test_result instead.";
    }

    upload_asset "$make_check_log";
    record_info 'Test finished with errors', "glibc test finished with errors! Find the test results in the asset $make_check_log";
}

1;
