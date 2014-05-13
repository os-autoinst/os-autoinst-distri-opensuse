use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $vars{DESKTOP} eq "kde";
}

sub run() {
    my $self = shift;
    ensure_installed("amarok");
    $self->start_audiocapture;
    x11_start_program("amarok http://openqa.opensuse.org/opensuse/audio/bar.oga");
    sleep 3;
    $self->assert_DTMF('123A456B789C*0#D');
    sleep 2;
    assert_screen 'test-amarok-1', 3;
    send_key "alt-y";    # use music path as collection folder
    assert_screen 'test-amarok-2', 3;
    send_key "ctrl-q";    # really quit (alt-f4 just backgrounds)
    sleep 2;
    wait_idle;
    x11_start_program("killall amarok") unless $vars{NICEVIDEO};    # to be sure that it does not interfere with later tests
}

1;
# vim: set sw=4 et:
