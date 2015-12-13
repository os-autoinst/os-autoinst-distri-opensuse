use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    $self->select_bootmenu_option('inst-onmediacheck', 1);

    # the timeout is insane - but SLE11 DVDs take almost forever
    assert_screen "mediacheck-ok", 3600;
    send_key "ret";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
