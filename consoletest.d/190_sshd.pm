use base "basetest";
use bmwqemu;

# check if sshd works
sub run() {
    my $self = shift;
    become_root();
    script_run('SuSEfirewall2 off');
    script_run('chkconfig sshd on');
    script_run("chkconfig sshd on && echo 'sshd_on' > /dev/$serialdev");
    wait_serial("sshd_on", 60) || die "enable sshd failed";
    script_run("rcsshd restart && echo 'sshd_restart' > /dev/$serialdev");    # will do nothing if it is already running
    wait_serial("sshd_restart", 60) || die "restart sshd failed";
    script_run('echo $?');
    script_run('rcsshd status');
    script_run('exit');
    assert_screen 'test-sshd-1', 3;
    wait_idle 5;
    script_run('ssh root@localhost -t echo LOGIN_SUCCESSFUL');
    my $ret = assert_screen "ssh-login", 60;

    if ( $ret->{needle}->has_tag("ssh-login") ) {
        type_string "yes\n";
    }
    sleep 3;
    sendpassword;
    type_string "\n";
    assert_screen "ssh-login-ok", 10;
}

sub test_flags() {
    return { 'milestone' => 1 };
}

1;
# vim: set sw=4 et:
