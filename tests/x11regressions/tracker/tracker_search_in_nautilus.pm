# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("nautilus");
    wait_idle;
    send_key "ctrl-f";
    sleep 2;
    type_string "newfile";
    wait_idle;
    send_key "ret";
    wait_idle;
    assert_screen 'gedit-launched', 3;    # should open file newfile
    send_key "alt-f4";
    sleep 2;                              #close gedit
    send_key "alt-f4";
    sleep 2;                              #close nautilus
}

1;
# vim: set sw=4 et:
