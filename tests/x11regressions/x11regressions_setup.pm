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

    # grant user permission to access serial port until next reboot
    script_sudo "chown $username /dev/$serialdev";

    # get permanent user permission to access serial port even if reboot
    script_sudo "gpasswd -a $username tty";

    # quit xterm
    type_string "exit\n";
}

1;
# vim: set sw=4 et:
