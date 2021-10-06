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
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    add_suseconnect_product(get_addon_fullname('phub'));
}

1;
