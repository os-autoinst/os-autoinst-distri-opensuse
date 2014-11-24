use base "kdestep";
use testapi;

sub run() {
    my $self = shift;
    ensure_installed("amarok");
    x11_start_program("amarok", 6, { valid => 1 } );
    assert_screen 'test-amarok-1', 3;
    send_key "alt-y";    # use music path as collection folder
    assert_screen 'test-amarok-2', 3;
    # a workaround for librivox authentication popup window.
    # and don't put this after opening oga file, per video
    # the window pop-up meanwhile x11_start_progran typeing,
    # and 40 sec to wait that window pop-up should enough
    if ( check_screen "librivox-authentication", 40 ) {
        send_key "alt-c";    # cancel librivox certificate
    }
    $self->start_audiocapture;
    x11_start_program("amarok -l http://" . get_var("OPENQA_HOSTNAME") . "/tests/" . get_var("TEST_ID") . "/data/1d5d9dD.oga");
    assert_screen 'test-amarok-3', 10;
    $self->assert_DTMF('159D');
    send_key "ctrl-q";    # really quit (alt-f4 just backgrounds)
}

1;
# vim: set sw=4 et:
