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
    assert_screen "before-package-selection";

    #send_key "ctrl-alt-shift-x"; sleep 3;
    select_console('install-shell');

    type_string "(cat .timestamp ; echo .packages.initrd: ; cat .packages.initrd; echo 'CAT_INITRD')>/dev/$serialdev\n";
    wait_serial 'CAT_INITRD';
    type_string "(echo .packages.root: ; cat .packages.root; echo 'PACKAGES_ROOT')>/dev/$serialdev\n";
    wait_serial 'PACKAGES_ROOT';
    type_string "ls -lR /update\n";
    save_screenshot;
    wait_idle;

    select_console('installation');
    assert_screen "inst-returned-to-yast", 15;

}

1;
# vim: set sw=4 et:
