use base "x11test";
use testapi;

sub run() {
    my $self = shift;

    # Launch vlc and play a 20 secs video file
    x11_start_program("vlc ~/data/test_video.ogv");
    # Check pause button as play button will being
    # pause state once the file plays properly
    assert_and_click 'vlc-pause-btn', 10;
    # After clicked pause button, check the interface
    assert_screen 'test-vlc', 5;
    send_key "alt-f4", 1;
}

1;
# vim: set sw=4 et:
