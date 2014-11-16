#!/usr/bin/perl -w
use strict;
use base "noupdatestep";
use bmwqemu;

sub run() {
    my $self = shift;

    # user setup
    assert_screen( "inst-usersetup", 10 );
    type_string($realname);
    send_key "tab";

    #sleep 1;
    send_key "tab";
    for ( 1 .. 2 ) {
        type_string("$password\t");
    }
    assert_screen( "inst-userinfostyped", 5 );
    if ( $vars{NOAUTOLOGIN} && !check_screen('autologindisabled') ) {
        send_key $cmd{"noautologin"};
        assert_screen( "autologindisabled", 5 );
    }
    if ( $vars{DOCRUN} ) {
        send_key $cmd{"otherrootpw"};
        assert_screen( "rootpwdisabled", 5 );
    }

    # done user setup
    send_key $cmd{"next"};

    # loading cracklib
    assert_screen( "inst-userpasswdtoosimple", 6 );
    send_key "ret";
}

1;
# vim: set sw=4 et:
