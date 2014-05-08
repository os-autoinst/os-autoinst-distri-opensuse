#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub run() {
    my $self = shift;

    waitforneedle( [qw/inst-welcome inst-betawarning/], 500 );    # live cds can take quite a long time to boot
                                                                  # we can't just wait for the needle as the beta popup may appear delayed and we're doomed
    waitidle(5);
    my $ret = waitforneedle( [qw/inst-welcome inst-betawarning/], 3 );

    if ( $ret->{needle}->has_tag("inst-betawarning") ) {
        send_key "ret";
        waitforneedle( "inst-welcome", 5 );
    }

    #	if($ENV{BETA}) {
    #		waitforneedle("inst-betawarning", 5);
    #		send_key "ret";
    #	} elsif (checkneedle("inst-betawarning", 2)) {
    #		mydie("beta warning found in non-beta");
    #	}

    # animated cursor wastes disk space, so it is moved to bottom right corner
    mouse_hide;

    #send_key "alt-o"; # beta warning
    waitidle;

    # license+lang
    if ( $ENV{HASLICENSE} ) {
        send_key $cmd{"accept"};    # accept license
    }
    waitforneedle( "languagepicked", 2 );
    send_key $cmd{"next"};
    if ( checkneedle( "langincomplete", 1 ) ) {
        send_key "alt-f";
    }
}

1;
# vim: set sw=4 et:
