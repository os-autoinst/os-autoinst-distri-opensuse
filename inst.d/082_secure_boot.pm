#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && $ENV{UEFI} && $ENV{SECUREBOOT};
}

sub run() {
    my $self = shift;

    # Make sure that we are in the installation overview with SB enabled
    waitforneedle("inst-overview-secureboot");

    $cmd{bootloader} = "alt-b" if checkEnv( 'VIDEOMODE', "text" );
    send_key $cmd{change};        # Change
    send_key $cmd{bootloader};    # Bootloader
    sleep 4;

    # Is secure boot enabled?
    waitforneedle( "bootloader-secureboot-enabled", 5 );
    send_key $cmd{accept};        # Accept
    sleep 2;
    send_key "alt-o";             # cOntinue
    waitidle;
}

1;
# vim: set sw=4 et:
