use base "basetest";
use bmwqemu;

sub is_applicable {
    return !$envs->{NICEVIDEO};    # && $envs->{BIGTEST};
}

sub run() {
    my $self = shift;
    $self->start_audiocapture;
    x11_start_program("firefox http://openqa.opensuse.org/opensuse/audio/bar.oga");
    sleep 3;
    $self->check_DTMF('123A456B789C*0#D');
    assert_screen 'test-firefox_audio-1', 3;
    send_key "alt-f4";
    sleep 2;
    send_key "ret", 1;             # confirm "save&quit"
}

1;
# vim: set sw=4 et:
