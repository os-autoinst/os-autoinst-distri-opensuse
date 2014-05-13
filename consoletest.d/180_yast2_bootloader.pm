use base "basetest";
use bmwqemu;

# test yast2 bootloader functionality
# https://bugzilla.novell.com/show_bug.cgi?id=610454

sub is_applicable() {
    return !$vars{LIVETEST};
}

sub run() {
    my $self = shift;
    script_sudo("/sbin/yast2 bootloader");
    my $ret = assert_screen "test-yast2_bootloader-1", 300;
    send_key "alt-o";     # OK => Close
    assert_screen 'exited-bootloader', 15;
    send_key "ctrl-l";
    script_run('echo "EXIT-$?" > /dev/serial');
    die unless wait_serial  "EXIT-0", 2 ;
    script_run('rpm -q hwinfo');
    $self->take_screenshot;
}

1;
# vim: set sw=4 et:
