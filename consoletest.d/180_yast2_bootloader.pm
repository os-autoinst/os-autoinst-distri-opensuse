use base "basetest";
use bmwqemu;

# test yast2 bootloader functionality
# https://bugzilla.novell.com/show_bug.cgi?id=610454

sub is_applicable() {
    return !$ENV{LIVETEST};
}

sub run() {
    my $self = shift;
    script_sudo("/sbin/yast2 bootloader");
    while (1) {
        my $ret = assert_screen "yast2_bootloader-initialed", 300;
        last if $ret->{needle}->has_tag("yast2_bootloader-initialed");
    }
    waitstillimage( 12, 60 );
    send_key "ctrl-l";    # redraw in case kernel painted on us
    sleep 2;
    assert_screen 'test-yast2_bootloader-1', 3;
    waitidle 5;
    send_key "alt-o";     # OK => Close # might just close warning on livecd
    sleep 2;
    send_key "alt-o";     # OK => Close
    waitstillimage( 16, 60 );
    $self->take_screenshot;
    waitidle 5;
    send_key "ctrl-l";
    script_run('echo $?');
    assert_screen "exited-bootloader", 2;
    script_run('rpm -q hwinfo');
    $self->take_screenshot;
}

1;
# vim: set sw=4 et:
