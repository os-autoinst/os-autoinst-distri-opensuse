#!/usr/bin/perl -w
use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{UPGRADE} && !$vars{AUTOYAST};
}

sub run() {

    while(my $ret = check_screen([qw/import-untrusted-gpg-key inst-overview/], 15)) {
        last if ($ret->{needle}->has_tag("inst-overview"));
        send_key "alt-c", 1;
    }

    # overview-generation
    # this is almost impossible to check for real
    assert_screen "inst-overview", 1;

    # preserve it for the video
    wait_idle 10;
}

1;
# vim: set sw=4 et:
