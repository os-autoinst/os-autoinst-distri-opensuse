# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install and execute hackbench and cyclictest from rt-tests suite
#          Ensure that packages rt-tests & ibmrtpkgs can be easily installed and successfully executed
#          Measured data is not relevant as long as test module runs in VM
# Maintainer: Martin Loviska <mloviska@suse.com>
# Tag: poo#46874

use base "opensusebasetest";
use testapi;
use utils 'zypper_call';

sub run {
    zypper_call 'in rt-tests ibmrtpkgs', log => 'rt_tests_zypper.log';
    assert_script_run "cyclictest -a -t -p 99 -l 100 -v";
    assert_script_run "hackbench -l 100";
}

1;
