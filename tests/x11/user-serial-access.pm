use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("xterm");
    sleep 2;
    script_sudo "chown $username /dev/$serialdev";
    assert_script_run("ls -la /dev/$serialdev");
    send_key "alt-f4";
}

sub test_flags() {
    return { 'important' => 1, 'milestone' => 1 };
}

1;
# vim: set sw=4 et:
