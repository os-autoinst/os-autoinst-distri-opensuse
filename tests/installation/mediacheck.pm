use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen "inst-bootmenu", 15;

    $self->bootmenu_down_to('inst-onmediacheck');
    send_key "ret";
    # the timeout is insane - but SLE11 DVDs take almost forever
    assert_screen "mediacheck-ok", 1600;
    send_key "ret";
}

sub test_flags() {
    return { 'fatal' => 1, 'important' => 1 };
}

1;
# vim: set sw=4 et:
