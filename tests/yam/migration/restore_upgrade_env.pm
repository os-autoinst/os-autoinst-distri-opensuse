# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Restore environmental variables which differ between the products involved in the upgrade.
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "opensusebasetest";
use testapi;
use migration 'reset_consoles_tty';

sub run {
    # Restore the original value of the variables
    my $env_content = '';
    foreach my $var (qw(AGAMA SCC_ADDONS SCC_URL VERSION)) {
        if (get_var($var . "_ENV")) {
            set_var($var, get_var($var . "_ENV"));
            $env_content .= "$var=" . get_var($var) . "\n";
        }
    }
    record_info('ENV', $env_content);
    # tty assignation might differ between product versions
    reset_consoles_tty();
}

1;
