use base "basetest";
use bmwqemu;

sub is_applicable() {
    return $vars{DESKTOP} eq "kde";
}

sub run() {
    my $self = shift;
    ensure_installed("amarok");
    x11_start_program("amarok");
    assert_screen 'test-amarok-1', 3;
    send_key "alt-y";    # use music path as collection folder
    assert_screen 'test-amarok-2', 3;
    $self->start_audiocapture;
    x11_start_program("amarok -l http://$vars{OPENQA_HOSTNAME}/test-data/$vars{DISTRI}/data/1d5d9dD.oga");
    assert_screen 'test-amarok-3', 10;
    $self->assert_DTMF('159D');
    send_key "ctrl-q";    # really quit (alt-f4 just backgrounds)
}

1;
# vim: set sw=4 et:
