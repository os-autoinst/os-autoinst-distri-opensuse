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
    foreach my $var (qw(VERSION SCC_ADDONS)) {
        set_var($var, get_var($var . "_ENV"));
        record_info($var, $var . '=' . get_var($var));
    }
    if (get_var('AGAMA_ENV')) {
        set_var('AGAMA', get_var('AGAMA_ENV'));
	record_info('AGAMA=', get_var('AGAMA_ENV'));
    }

    # tty assignation might differ between product versions
    reset_consoles_tty();
}

1;
