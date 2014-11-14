use strict;
use base "noupdatestep";
use bmwqemu;

sub run() {
    waitstillimage();
    send_key $cmd{"next"};
    assert_screen "after-paritioning";
}

1;
# vim: set sw=4 et:
