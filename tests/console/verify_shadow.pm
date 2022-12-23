# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary:  Check if all users has some value in the password field
# (bsc#973639, bsc#974220, bsc#971804 and bsc#965852)
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use parent 'y2_module_consoletest';
use testapi;

sub run {
    assert_script_run("! getent shadow | grep -E \"^[^:]+::\"",
        fail_message => "Not all users have defined passwords");
}

1;
