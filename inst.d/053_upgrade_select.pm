use strict;
use base "installstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$ENV{LIVECD} && $ENV{UPGRADE};
}

sub run() {
    my $self = shift;

    $self->check_screen;
    send_key $cmd{"next"}, 1;
    assert_screen  "remove-repository", 10 ;
    send_key $cmd{"next"}, 1;
    assert_screen  "installation-settings", 10 ;
}

1;
# vim: set sw=4 et:
