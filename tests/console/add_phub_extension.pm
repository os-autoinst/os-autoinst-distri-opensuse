# SUSE"s openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add phub extension for required dependecnies
# Maintainer: Jozef Pupava <jpupava@suse.cz>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use registration qw(add_suseconnect_product get_addon_fullname is_phub_ready);

sub run {
    select_serial_terminal;

    return unless is_phub_ready();

    eval { add_suseconnect_product(get_addon_fullname('phub')); };
    if ($@) {
        if (check_var('BETA', '1')) {
            force_soft_failure('poo#120879, PackageHub installation might fail in early development');
            set_var('PHUB_READY', 0);
        }
        else {
            die "$@";
        }
    }
}

# Add milestone flag to save setup into the snapshot which
# packagehub is activated
sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
