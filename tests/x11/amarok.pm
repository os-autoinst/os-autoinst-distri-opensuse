use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    ensure_installed("amarok");
    x11_start_program("amarok", 6, { valid => 1 } );
    assert_screen 'test-amarok-1', 3;
    send_key "alt-y";    # use music path as collection folder
    # a workaround for librivox authentication popup window.
    # and don't put this after opening oga file, per video
    # the window pop-up meanwhile x11_start_progran typeing,
    # and 40 sec to wait that window pop-up should enough
    if ( check_screen "librivox-authentication", 40 ) {
        send_key "alt-c";    # cancel librivox certificate
    }
    assert_screen 'test-amarok-2', 3;
    # do not playing audio file as we have not testdata if NICEVIDEO
    if (!get_var("NICEVIDEO")) {
        $self->start_audiocapture;
        x11_start_program("amarok -l ~/data/1d5d9dD.oga");
        assert_screen 'test-amarok-3', 10;
        $self->assert_DTMF('159D');
    }
    send_key "ctrl-q";    # really quit (alt-f4 just backgrounds)
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_captured_audio();
}

1;
# vim: set sw=4 et:
