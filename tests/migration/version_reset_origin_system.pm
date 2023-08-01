# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Change the VERSION to ORIGIN_SYSTEM_VERSION
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi qw(get_required_var set_var);
use migration qw(reset_consoles_tty);

sub run {
    # Do NOT use HDDVERSION because it might be changed in another test
    # module, such as: reboot_and_install.pm
    my $original_version = get_required_var('ORIGIN_SYSTEM_VERSION');

    set_var('VERSION', $original_version);
    reset_consoles_tty;
}

1;

