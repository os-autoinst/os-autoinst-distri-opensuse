use strict;
use base "y2logsstep";
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && !$vars{LIVECD} && $vars{UPGRADE};
}

sub run() {
    my $self = shift;

    # hardware detection can take a while
    assert_screen "select-for-update", 100;
    send_key $cmd{"next"}, 1;
    assert_screen "remove-repository", 10;
    send_key $cmd{"next"}, 1;
#    assert_screen "update-installation-overview", 15;
}

1;
# vim: set sw=4 et:
