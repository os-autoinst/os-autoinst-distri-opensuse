use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("gnome-music");
    assert_screen 'test-gnome-music-1', 3;
    send_key "alt-f4",                  1;
}

1;
# vim: set sw=4 et:
