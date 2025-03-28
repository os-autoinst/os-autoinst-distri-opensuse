# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate registered extensions against the extension list.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'consoletest';
use strict;
use warnings;
use utils 'zypper_call';
use testapi;

sub run {
    select_console 'root-console';

    my @addon_list = split(/,/, get_var('ADDONS'));

    zypper_call("search -t product");
    foreach (@addon_list) { zypper_call("search -i -t product $_"); }
    script_run("SUSEConnect -s");
    foreach (@addon_list) { assert_script_run("SUSEConnect -s | grep -i $_"); }
}

1;
