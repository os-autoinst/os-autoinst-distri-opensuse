use base "gnomestep";
use strict;
use bmwqemu;

# test eye of gnome image viewer


# this part contains the steps to run this test
sub run() {
    my $self = shift;
    x11_start_program("eog /usr/share/wallpapers/SLEdefault/contents/images/1280x1024.jpg");
    sleep 2;
    assert_screen 'test-eog-1', 3;
    sleep 2;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
