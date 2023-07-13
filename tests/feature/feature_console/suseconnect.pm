# Feature tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: [316585] Drop suseRegister
# Maintainer: QE Security <none@suse.de>
# Tags: tc#1480023

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';

    #Check SUSEConnect is installed
    assert_script_run('rpm -q SUSEConnect');
    save_screenshot;

    #Check suseRegister is not installed
    assert_script_run('! rpm -q suseRegister');
    save_screenshot;
}

1;
