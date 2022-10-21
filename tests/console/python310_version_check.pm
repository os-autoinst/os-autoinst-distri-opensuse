# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: python310
# Summary: Run python310 testsuite
# - Test suitable only for SLE15SP4+
# - Check that Python 3.6 is the main version installed
# - Check that Python 3.10 is available to install
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
            # Factory default Python3 version for SLE15-SP4 should be 3.6
            die("Python default version differs from 3.6");
        }
        add_suseconnect_product('sle-module-python3');
    }

    my @python310_results = split "\n", script_output("zypper se python310 | awk -F \'|\' \'/python310/ {gsub(\" \", \"\"); print \$2}\'");
    if ((scalar(@python310_results) == 0) || ($python310_results[0] ne "python310")) {
        die("Python 3.10 not found in the repositories\n\n");
    }
    else {
        zypper_call("install python310");
        # Running classic testing algorithm 'man_or_boy'. More info at:
        # https://rosettacode.org/wiki/Man_or_boy_test
        assert_script_run("curl -O " . data_url("console/man_or_boy.py"));
        my $man_or_boy = script_output("python3.10 man_or_boy.py");
        if ($man_or_boy != -67) {
            die("Execution of 'man_or_boy.py' not correct\n");
        }
    }
}

1;
