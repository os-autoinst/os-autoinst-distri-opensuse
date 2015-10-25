#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    assert_screen "inst-rootpassword", 6;
    for (1 .. 2) {
        type_string "$password\t";
        sleep 1;
    }
    assert_screen "rootpassword-typed", 3;
    send_key $cmd{"next"};

    # PW too easy (cracklib)
    # If check_screen added to workaround bsc#937012
    if (check_screen('inst-userpasswdtoosimple', 13)) {
        send_key "ret";
    }
    else {
        record_soft_failure;
    }
}

1;
# vim: set sw=4 et:
