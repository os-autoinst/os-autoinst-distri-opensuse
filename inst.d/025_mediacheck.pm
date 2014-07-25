use base "installbasetest";
use strict;
use bmwqemu;

sub is_applicable() {
    my $self = shift;
    return $self->SUPER::is_applicable && $vars{MEDIACHECK};
}

sub run {
    my $self = shift;
    assert_screen "mediacheck-ok", 300;
    send_key "ret";
}

1;
# vim: set sw=4 et:
