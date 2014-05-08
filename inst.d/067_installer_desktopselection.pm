#!/usr/bin/perl -w
use strict;
use base "basenoupdate";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    $self->SUPER::is_applicable && !$ENV{LIVECD};
}

sub run() {
    my %desktopkeys = ( kde => "k", gnome => "g", xfce => "x", lxde => "l", minimalx => "m", textmode => "i" );
    waitforneedle( "desktop-selection", 30 );
    my $d = $ENV{DESKTOP};
    diag "selecting desktop=$d";
    $ENV{ uc($d) } = 1;
    my $key = "alt-$desktopkeys{$d}";
    if ( $d eq "kde" ) {

        # KDE is default
    }
    elsif ( $d eq "gnome" ) {
        send_key $key;
        waitforneedle( "gnome-selected", 3 );
    }
    else {    # lower selection level
        send_key "alt-o";    #TODO translate
        waitforneedle( "other-desktop", 3 );
        send_key $key;
        sleep 3;            # needles for else cases missing
    }
    send_key $cmd{"next"};

    # ending at partition layout screen
}

1;
# vim: set sw=4 et:
