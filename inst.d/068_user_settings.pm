#!/usr/bin/perl -w
use strict;
use base "basenoupdate";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{UPGRADE};
}

sub run() {
    my $self = shift;

    # user setup
    assert_screen  "inst-usersetup", 5 ;
    type_string $realname;
    send_key "tab";

    #sleep 1;
    send_key "tab";
    for ( 1 .. 2 ) {
        type_string "$password\t";
    }
    assert_screen  "inst-userinfostyped", 5 ;
    if ( $vars{NOAUTOLOGIN} ) {
        my $ret;
        for (my $counter = 10; $counter > 0; $counter--) {
            $ret = check_screen  "autologindisabled", 3 ;
            if ( defined($ret) ) {
                last;
            }
            else {
                ++$self->{dents};
                send_key $cmd{"noautologin"};
            }
        }
        # report the failure or green
        unless ( defined($ret) ) {
            assert_screen  "autologindisabled", 1 ;
        }
    }
    if ( $vars{DOCRUN} ) {
        send_key $cmd{"otherrootpw"};
        assert_screen  "rootpwdisabled", 5 ;
    }

    # done user setup
    send_key $cmd{"next"};

    # loading cracklib
    assert_screen  "inst-userpasswdtoosimple", 6 ;
    send_key "ret";

    #sleep 1;
    # PW too easy (only chars)
    #send_key "ret";
    if ( $vars{DOCRUN} ) {    # root user
        wait_idle;
        for ( 1 .. 2 ) {
            type_string "$password\t";
            sleep 1;
        }
        assert_screen  "rootpassword-typed", 3 ;
        send_key $cmd{"next"};

        # loading cracklib
        wait_idle 6;

        # PW too easy (cracklib)
        send_key "ret";
        wait_idle;
    }
}

1;
# vim: set sw=4 et:
