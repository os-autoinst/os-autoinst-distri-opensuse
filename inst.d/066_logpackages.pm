#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    $self->SUPER::is_applicable && !$ENV{LIVECD} && !$ENV{NICEVIDEO} && !$ENV{UPGRADE};
}

sub run() {
    my $self = shift;
    waitforneedle("before-package-selection");

    #send_key "ctrl-alt-shift-x"; sleep 3;
    send_key "ctrl-alt-f2";
    waitforneedle("inst-console");
    type_string "(cat .timestamp ; echo .packages.initrd: ; cat .packages.initrd)>/dev/$serialdev\n";
    type_string "(echo .packages.root: ; cat .packages.root)>/dev/$serialdev\n";
    waitforneedle( "inst-packagestyped", 150 );
    type_string "ls -lR /update\n";
    $self->take_screenshot;
    waitidle;

    #send_key "ctrl-d"; sleep 3;
    if ( checkEnv( 'VIDEOMODE', 'text' ) ) {
        send_key "ctrl-alt-f1";
    }
    else {
        send_key "ctrl-alt-f7";
    }
    waitforneedle( "inst-returned-to-yast", 15 );

}

1;
# vim: set sw=4 et:
