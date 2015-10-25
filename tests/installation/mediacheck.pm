use base "opensusebasetest";
use strict;
use testapi;

sub run {
    my $self = shift;

    assert_screen "inst-bootmenu", 15;

    if (get_var('OFW')) {
        send_key_until_needlematch 'inst-onmediacheck', 'up';
    }
    else {
        send_key_until_needlematch('inst-onmediacheck', 'down', 10, 5);
    }

    send_key "ret";
    # the timeout is insane - but SLE11 DVDs take almost forever
    assert_screen "mediacheck-ok", 3600;
    send_key "ret";
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
