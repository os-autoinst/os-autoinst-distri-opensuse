# X11 regression tests
#
# Copyright © 2016 SUSE LLC
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

    x11_start_program("xterm");

    # grant permission for default user to access serial port
    type_string "xdg-su -c 'chown $username /dev/$serialdev'\n";
    wait_still_screen;

    if ($password) {
        type_password;
        send_key "ret";
    }

    wait_still_screen;
    save_screenshot;

    # quit xterm
    type_string "exit\n";
}

1;
# vim: set sw=4 et:
