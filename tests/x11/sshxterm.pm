use base "x11test";
use testapi;

sub run() {
    my $self = shift;
    mouse_hide(1);
    x11_start_program("xterm");
    script_run("ssh -XC root\@localhost xterm");
    type_string "yes\n";
    wait_idle 6;
    type_string "$password\n";
    sleep 2;
    for (1 .. 13) { send_key "ret" }
    ensure_valid_prompt();
    type_string "echo If you can see this text, ssh-X-forwarding  is working.\n";
    sleep 2;
    assert_screen 'test-sshxterm-1', 3;
    send_key "alt-f4";
    sleep 1;
    send_key "alt-f4";
    sleep 2;
}

1;
# vim: set sw=4 et:
