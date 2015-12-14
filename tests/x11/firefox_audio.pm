use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    start_audiocapture;
    x11_start_program("firefox " . autoinst_url . "/data/1d5d9dD.oga");
    assert_screen 'test-firefox_audio-1', 35;
    sleep 1;    # at least a second of silence
    assert_recorded_sound('DTMF-159D');
    send_key "alt-f4";
    if (check_screen('firefox-save-and-quit', 4)) {
        # confirm "save&quit"
        send_key "ret";
    }
}

1;
# vim: set sw=4 et:
