#!/usr/bin/perl -w
use strict;
use base "basenoupdate";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$ENV{UPGRADE};
}

sub run() {
    my $self = shift;

    # user setup
    waitforneedle( "inst-usersetup", 5 );
    sendautotype($realname);
    sendkey "tab";

    #sleep 1;
    sendkey "tab";
    for ( 1 .. 2 ) {
        sendautotype("$password\t");
    }
    waitforneedle( "inst-userinfostyped", 5 );
    if ( $ENV{NOAUTOLOGIN} ) {
        my $ret;
        for (my $counter = 10; $counter > 0; $counter--) {
            $ret = checkneedle( "autologindisabled", 3 );
            if ( defined($ret) ) {
                last;
            }
            else {
                ++$self->{dents};
                sendkey $cmd{"noautologin"};
            }
        }
        # report the failure or green
        unless ( defined($ret) ) {
            waitforneedle( "autologindisabled", 1 );
        }
    }
    if ( $ENV{DOCRUN} ) {
        sendkey $cmd{"otherrootpw"};
        waitforneedle( "rootpwdisabled", 5 );
    }

    # done user setup
    sendkey $cmd{"next"};

    # loading cracklib
    waitforneedle( "inst-userpasswdtoosimple", 6 );
    sendkey "ret";

    #sleep 1;
    # PW too easy (only chars)
    #sendkey "ret";
    if ( $ENV{DOCRUN} ) {    # root user
        waitidle;
        for ( 1 .. 2 ) {
            sendautotype("$password\t");
            sleep 1;
        }
        waitforneedle( "rootpassword-typed", 3 );
        send_key $cmd{"next"};

        # loading cracklib
        waitidle 6;

        # PW too easy (cracklib)
        send_key "ret";
        waitidle;
    }
}

1;
# vim: set sw=4 et:
