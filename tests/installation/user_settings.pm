#!/usr/bin/perl -w
use strict;
use base "y2logsstep";
use testapi;

sub run() {
    my $self = shift;

    # user setup
    assert_screen "inst-usersetup", 10;
    type_string $realname;
    send_key "tab";

    #sleep 1;
    send_key "tab";
    for (1 .. 2) {
        type_string "$password\t";
    }
    assert_screen "inst-userinfostyped", 10;
    if (get_var("NOAUTOLOGIN") && !check_screen('autologindisabled')) {
        send_key $cmd{"noautologin"};
        assert_screen "autologindisabled", 5;
    }
    if (get_var("DOCRUN")) {
        send_key $cmd{"otherrootpw"};
        assert_screen "rootpwdisabled", 5;
    }

    # done user setup
    send_key $cmd{"next"};

    # loading cracklib
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
