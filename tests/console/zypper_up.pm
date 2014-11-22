use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;

    become_root();

    # Killall is used here, make sure that is installed
    script_run("zypper -n -q in psmisc");

    script_run("zypper patch -l && echo 'worked' > /dev/$serialdev");
    my $ret = assert_screen( [qw/test-zypper_up-confirm test-zypper_up-nothingtodo/] );
    if ( $ret->{needle}->has_tag("test-zypper_up-confirm") ) {
        type_string "y\n";
    }
    die "zypper failed" unless wait_serial "worked", 700;
    script_run("zypper patch -l && echo 'worked' > /dev/$serialdev");    # first one might only have installed "update-test-affects-package-manager"
    if ( check_screen "test-zypper_up-confirm" ) {
        type_string "y\n";
    }
    die "zypper failed" unless wait_serial "worked", 700;
    script_run("rpm -q libzypp zypper");
    check_screen "rpm-q-libzypp", 5;
    save_screenshot;

    # XXX: does this below make any sense? what if updates got
    # published meanwhile?
    send_key "ctrl-l";    # clear screen to see that second update does not do any more
    script_run("zypper -n -q patch");
    script_run('echo $?');
    script_run('exit');
    assert_screen 'test-zypper_up-1', 3;
}

sub test_flags() {
    return { 'milestone' => 1 };
}

1;
# vim: set sw=4 et:
