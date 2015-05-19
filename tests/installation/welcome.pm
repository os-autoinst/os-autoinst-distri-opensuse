#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    if (get_var("BETA")) {
        assert_screen "inst-betawarning", 500;
        send_key "ret";
        assert_screen "inst-welcome", 10;
    }
    else {
        assert_screen "inst-welcome", 500;
    }

    wait_idle;
    mouse_hide;

    # license+lang
    if ( get_var("HASLICENSE") ) {
        send_key $cmd{"accept"};    # accept license
    }
    assert_screen "languagepicked", 2;
    send_key $cmd{"next"};
    if ( !check_var('INSTLANG', 'en_US') && check_screen "langincomplete", 1  ) {
        send_key "alt-f";
    }
}

1;
# vim: set sw=4 et:
