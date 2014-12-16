use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen "inst-bootmenu", 15;

    $self->bootmenu_down_to('inst-onmemtest');
    send_key "ret";
    assert_screen "pass-complete", 700;
    send_key "esc";
}

sub test_flags() {
    return { 'fatal' => 1, 'important' => 1 };
}

1;
# vim: set sw=4 et:
