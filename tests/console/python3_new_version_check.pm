# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: python31?
# Summary: Run python310 testsuite
# - Test suitable only for SLE15SP4+
# - Check that Python 3.6 is the main version installed
# - Check that Python 3.1? is available to install
# - Run some basic test (man_or_boy.py)
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils;
use utils "zypper_call";
use python_version_utils;
use registration "add_suseconnect_product";

sub run {
    select_serial_terminal;
    # Test system python3 version
    my $system_python_version = get_system_python_version();
    record_info("System python version", "$system_python_version");
    assert_script_run("[ -f man_or_boy.py ] || curl -O " . data_url("console/man_or_boy.py") . " || true");

    my $python3_spec_release = script_output("rpm -q $system_python_version | awk -F \'-\' \'{print \$2}\'");
    record_info("python_verison", $python3_spec_release);
    # Python313 is the default python version for sle16
    die("Python default version differs from 3.13") if ((package_version_cmp($python3_spec_release, "3.13") < 0) && is_sle('>=16'));
    if (is_sle('>=15-SP4') && is_sle('<16')) {
        if ((package_version_cmp($python3_spec_release, "3.6") < 0) ||
            (package_version_cmp($python3_spec_release, "3.7") >= 0)) {
            # Factory default Python3 version for SLE15-SP4+ should be 3.6
            die("Python default version differs from 3.6");
        }
    }
    record_info("Testing system python version $python3_spec_release", "python $python3_spec_release is tested now");
    run_python_test("/usr/bin/python3");

    # Test all avaiable new python3 versions if any
    my @python3_versions = get_available_python_versions();
    foreach my $python3_spec_release (@python3_versions) {
        record_info("Testing $python3_spec_release", "$python3_spec_release is tested now");
        my $python3_version = get_python3_binary($python3_spec_release);
        zypper_call("install $python3_spec_release-base");
        # Running classic testing algorithm 'man_or_boy'. More info at:
        # https://rosettacode.org/wiki/Man_or_boy_test
        run_python_test($python3_version);
    }
}

sub run_python_test () {
    my ($python_package) = @_;
    my $man_or_boy = script_output("$python_package man_or_boy.py");
    if ($man_or_boy != -67) {
        die("Execution of 'man_or_boy.py' with $python_package is not correct\n");
    }

}

sub post_run_hook {
    remove_installed_pythons();
}

sub post_fail_hook {
    select_console 'log-console';
    assert_script_run 'save_y2logs /tmp/python3_new_version_check_y2logs.tar.bz2';
    upload_logs '/tmp/python3_new_version_check_y2logs.tar.bz2';
}

1;
