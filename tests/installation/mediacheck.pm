use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen "inst-bootmenu", 15;

    for ( 1 .. 10 ) {
        last if check_screen "inst-onmediacheck", 2;
        send_key "down";
    }
    assert_screen "inst-onmediacheck", 3;
    send_key "ret";
    assert_screen "mediacheck-ok", 300;
    send_key "ret";
}

sub test_flags() {
    return { 'fatal' => 1, 'important' => 1 };
}

1;
# vim: set sw=4 et:
