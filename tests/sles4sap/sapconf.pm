# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: sapconf availability and basic commands to tuned-adm
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "x11test";
use strict;
use testapi;

sub run {
    my ($self) = @_;

    x11_start_program('xterm');
    assert_screen('xterm');

    script_sudo("sapconf status");
    assert_screen 'sapconf-status', 10;
    die "Command 'sapconf status' output is not recognized" unless match_has_tag "sapconf-status";

    foreach my $cmd (qw(start hana b1 ase sybase bobj)) {
        type_string "clear\n";
        assert_script_sudo("sapconf $cmd");
        assert_screen 'sapconf-fwd2tuned-adm', 10;
        die "Command 'sapconf $cmd' output is not recognized" unless match_has_tag "sapconf-fwd2tuned-adm";
    }

    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
