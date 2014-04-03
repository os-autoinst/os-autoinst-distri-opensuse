#!/usr/bin/perl -w
use strict;
use base "basenoupdate";
use bmwqemu;

# this test case are copied from 065_installer_timezone to adapt
# LiveCD installer excuses before then partition setup
sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && $ENV{LIVECD};
}

sub run() {
    waitforneedle( "inst-timezone", 125 ) || die 'no timezone';
    sendkey $cmd{"next"};
}

1;
