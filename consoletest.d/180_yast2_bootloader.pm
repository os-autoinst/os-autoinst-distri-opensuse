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
        my $ret = waitforneedle( "yast2_bootloader-initialed", 300 );
        last if $ret->{needle}->has_tag("yast2_bootloader-initialed");
    }
    waitstillimage( 12, 60 );
    sendkey "ctrl-l";    # redraw in case kernel painted on us
    sleep 2;
    $self->check_screen;
    waitidle 5;
    sendkey "alt-o";     # OK => Close # might just close warning on livecd
    sleep 2;
    sendkey "alt-o";     # OK => Close
    waitstillimage( 16, 60 );
    $self->take_screenshot;
    waitidle 5;
    sendkey "ctrl-l";
    script_run('echo $?');
    waitforneedle( "exited-bootloader", 2 );
    script_run('rpm -q hwinfo');
    $self->take_screenshot;
}

1;
