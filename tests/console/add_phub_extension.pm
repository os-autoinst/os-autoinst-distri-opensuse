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
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    select_serial_terminal;

    add_suseconnect_product(get_addon_fullname('phub'));
}

# Add milestone flag to save setup into the snapshot which
# packagehub is activated
sub test_flags {
    return {milestone => 1};
}

1;
