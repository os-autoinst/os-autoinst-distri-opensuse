use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    $self->select_bootmenu_option('inst-onmemtest', 1);
    assert_screen "pass-complete", 700;
    send_key "esc";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
