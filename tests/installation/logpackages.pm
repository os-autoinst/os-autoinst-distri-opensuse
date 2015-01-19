#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;
    assert_screen "before-package-selection";

    #send_key "ctrl-alt-shift-x"; sleep 3;
    send_key "ctrl-alt-f2";
    assert_screen "inst-console";
    type_string "(cat .timestamp ; echo .packages.initrd: ; cat .packages.initrd; echo 'CAT_INITRD')>/dev/$serialdev\n";
    wait_serial 'CAT_INITRD';
    type_string "(echo .packages.root: ; cat .packages.root; echo 'PACKAGES_ROOT')>/dev/$serialdev\n";
    wait_serial 'PACKAGES_ROOT';
    type_string "ls -lR /update\n";
    save_screenshot;
    wait_idle;

    #send_key "ctrl-d"; sleep 3;
    if ( check_var( 'VIDEOMODE', 'text' ) ) {
        send_key "ctrl-alt-f1";
    }
    else {
        send_key "ctrl-alt-f7";
    }
    assert_screen "inst-returned-to-yast", 15;

}

1;
# vim: set sw=4 et:
