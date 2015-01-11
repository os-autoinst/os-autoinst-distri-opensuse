use base "installbasetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

use bmwqemu ();

sub key_round($$) {
    my ($tag, $key) = @_;

    my $counter = 30;
    while ( !check_screen( $tag, 3 ) ) {
        send_key $key;
        if (!$counter--) {
            # DIE!
            assert_screen $tag, 1;
        }
    }
}

sub run() {
    my ($self) = @_;

    assert_screen "qa-net-selection", 300;
    $bmwqemu::backend->relogin_vnc();

    key_round "qa-net-selection-" . get_var('DISTRI') . "-" . get_var("VERSION"), 'down';
    send_key 'ret';
    key_round "qa-net-nfs", 'down';
    send_key 'ret';
    key_round "qa-net-x11", 'down';
    send_key 'ret';
}

1;

# vim: set sw=4 et:
