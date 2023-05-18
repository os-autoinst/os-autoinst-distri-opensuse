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
use registration "add_suseconnect_product";

sub run {
    select_serial_terminal;
    if (is_sle('>=15-SP4')) {
        my $python_version = script_output("rpm -q python3 | awk -F \'-\' \'{print \$2}\'");
        if ((package_version_cmp($python_version, "3.6") < 0) ||
            (package_version_cmp($python_version, "3.7") >= 0)) {
            # Factory default Python3 version for SLE15-SP4+ should be 3.6
            die("Python default version differs from 3.6");
        }
        add_suseconnect_product('sle-module-python3');
    }

    # Test all avaiable new python3 versions if any
    my $ret = zypper_call('se "python3[0-9]*"', exitcode => [0, 104]);
    die('No new python3 packages available') if ($ret == 104);
    my @python3_versions = split(/\n/, script_output(qq[zypper se 'python3[0-9]*' | awk -F '|' '/python3[0-9]/ {gsub(" ", ""); print \$2}' | awk -F '-' '{print \$1}' | uniq]));
    record_info("Available versions", "All available new python3 versions are: @python3_versions");
    my $sub_version;
    foreach my $python3_version (@python3_versions) {
        record_info("Testing $python3_version", "$python3_version is tested now");
        $sub_version = substr($python3_version, 7);
        zypper_call("install $python3_version");
        # Running classic testing algorithm 'man_or_boy'. More info at:
        # https://rosettacode.org/wiki/Man_or_boy_test
        assert_script_run("[ -f man_or_boy.py ] || curl -O " . data_url("console/man_or_boy.py") . " || true");
        my $man_or_boy = script_output("python3.$sub_version man_or_boy.py");
        if ($man_or_boy != -67) {
            die("Execution of 'man_or_boy.py' with $python3_version is not correct\n");
        }
    }
}

sub post_fail_hook {
    select_console 'log-console';
    assert_script_run 'save_y2logs /tmp/python3_new_version_check_y2logs.tar.bz2';
    upload_logs '/tmp/python3_new_version_check_y2logs.tar.bz2';
}

1;
