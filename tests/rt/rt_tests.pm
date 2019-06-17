# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Install and execute hackbench and cyclictest from rt-tests suite
#          Ensure that packages rt-tests & ibmrtpkgs can be easily installed and successfully executed
#          Measured data is not relevant as long as test module runs in VM
# Maintainer: Martin Loviska <mloviska@suse.com>
# Tag: poo#46874

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    select_console 'root-console';
    zypper_call("in rt-tests ibmrtpkgs", log => 'rt_tests_zypper.log');
    assert_script_run "cyclictest -a -t -p 99 -l 100 -v";
    assert_script_run "hackbench -l 100";
}

1;
