use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    $self->start_audiocapture;
    x11_start_program("firefox " . get_var("AUTOINSTURL") . "/data/1d5d9dD.oga");
    sleep 3;
    $self->assert_DTMF('159D');
    assert_screen 'test-firefox_audio-1', 3;
    send_key "alt-f4";
    sleep 2;
    send_key "ret", 1;             # confirm "save&quit"
}

1;
# vim: set sw=4 et:
