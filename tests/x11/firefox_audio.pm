use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    $self->start_audiocapture;
    x11_start_program("firefox " . autoinst_url . "/data/1d5d9dD.oga");
    assert_screen 'test-firefox_audio-1', 35;
    $self->assert_DTMF('159D');
    send_key "alt-f4";
     if (check_screen('firefox-save-and-quit', 4)) {
       # confirm "save&quit"
       send_key "ret";
    }
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_captured_audio();
}

1;
# vim: set sw=4 et:
