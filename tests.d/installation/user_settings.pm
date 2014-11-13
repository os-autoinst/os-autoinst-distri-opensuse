#!/usr/bin/perl -w
use strict;
use base "basenoupdate";
use bmwqemu;

sub is_applicable() {
    my $self = shift;

    # sles doesn't have user settings apparently
    return $self->SUPER::is_applicable && !$vars{UPGRADE} && !$vars{AUTOYAST};
}

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

    assert_screen( "inst-rootpassword", 6 );
    for ( 1 .. 2 ) {
        type_string("$password\t");
        sleep 1;
    }
    assert_screen( "rootpassword-typed", 3 );
    send_key $cmd{"next"};

    # PW too easy (cracklib)
    assert_screen( "inst-userpasswdtoosimple", 10 );
    send_key "ret";
}

1;
