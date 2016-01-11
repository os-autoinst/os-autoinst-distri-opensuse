# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # Make sure that we are in the installation overview with SB enabled
    assert_screen "inst-overview-secureboot";

    $cmd{bootloader} = "alt-b" if check_var('VIDEOMODE', "text");
    send_key $cmd{change};        # Change
    send_key $cmd{bootloader};    # Bootloader
    sleep 4;

    # Is secure boot enabled?
    assert_screen "bootloader-secureboot-enabled", 5;
    send_key $cmd{accept};        # Accept
    sleep 2;
    send_key "alt-o";             # cOntinue
    wait_idle;
}

1;
# vim: set sw=4 et:
