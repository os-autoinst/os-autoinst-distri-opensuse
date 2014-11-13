#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    return $vars{LVM} && !$vars{AUTOYAST};
}

sub run() {
    my $self = shift;

    # workaround for new style
    my $closedialog;
    my $ret = assert_screen ['partioning-edit-proposal-button'], 40;
    send_key "alt-d";
    sleep 2;

    send_key "alt-l", 1;    # enable LVM-based proposal
    if ( $vars{ENCRYPT} ) {
        send_key "alt-y", 1;
        assert_screen "inst-encrypt-password-prompt";
        sendpassword;
        send_key "tab";
        sendpassword;
        send_key "ret", 1;
        assert_screen "partition-cryptlvm-summary", 3;
    }
    else {
        assert_screen "partition-lvm-summary", 3;
    }
    wait_idle 5;
    send_key "alt-o";
}

1;
# vim: set sw=4 et:
