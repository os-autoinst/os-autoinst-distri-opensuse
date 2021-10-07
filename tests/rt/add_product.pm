# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Add RT product installation workaround
# Maintainer: QE Kernel <kernel-qa@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;

sub run() {
    record_soft_failure 'poo#96158 - Adding RT product to control.xml';
    assert_screen 'startshell', 90;
    assert_script_run 'sed -i \'/./{H;$!d} ; x ; s/\s*<\/base_product>\s*<\/base_products>/<\/base_product><base_product><display_name>SUSE Linux Enterprise Real Time 15 SP3<\/display_name><name>SLE_RT<\/name><version>15\.3<\/version><register_target>sle-15-\$arch<\/register_target><archs>x86_64<\/archs><\/base_product><\/base_products>/\' control.xml';
    assert_script_run 'sed -i \'1d\' control.xml';
    script_run 'exit', timeout => 0;
}

1;
