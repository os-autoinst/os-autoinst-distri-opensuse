# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Restore environmental variables which differ between the products involved in the upgrade.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use migration 'reset_consoles_tty';

sub run {
    # Restore the original value of the variables
    foreach my $var (qw(AGAMA SCC_ADDONS VERSION)) {
        if (get_var($var . "_ENV")) {
            set_var($var, get_var($var . "_ENV"));
            record_info($var, $var . '=' . get_var($var));
        }
    }

    # tty assignation might differ between product versions
    reset_consoles_tty();
}

1;
