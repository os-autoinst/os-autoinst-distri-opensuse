# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: write instsys and initrd package lists to log
#    this allows to better check and compare versions
#    to find what might have introduced a bug
#    or if the new version with a proposed fix is already included.
# G-Maintainer: Bernhard M. Wiedemann <bernhard+osautoinst lsmod de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;
    assert_screen "before-package-selection";

    #send_key "ctrl-alt-shift-x"; sleep 3;
    select_console('install-shell');

    script_run "(cat /.timestamp ; echo /.packages.initrd: ; cat /.packages.initrd) > /dev/$serialdev";
    script_run "(echo /.packages.root: ; cat /.packages.root) > /dev/$serialdev";
    save_screenshot;

    select_console('installation');
    assert_screen "inst-returned-to-yast", 15;
}

1;
# vim: set sw=4 et:
