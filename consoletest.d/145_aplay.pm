use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;
    script_sudo("~/data/install alsa-utils");
    wait_serial("zypper-0") || die;
    script_run('clear');
    script_run('set_default_volume -f');
    $self->start_audiocapture;
    script_run("aplay ~/data/bar.wav ; echo aplay-\$? > /dev/$serialdev");
    wait_serial('aplay-0') || die;
    save_screenshot;
    $self->assert_DTMF('123A456B789C*0#D');
    script_run('alsamixer');
    sleep 1;
    assert_screen 'test-aplay-2', 3;
    send_key "esc";
    send_key "esc";
}

1;
# vim: set sw=4 et:
