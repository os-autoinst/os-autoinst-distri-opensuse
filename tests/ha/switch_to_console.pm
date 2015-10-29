use base "hacluster";
use testapi;

use ttylogin;

sub run() {
    my $self = shift;

    wait_idle;
    # let's see how it looks at the beginning
    save_screenshot;

    # verify there is a text console on tty1
    send_key "ctrl-alt-f1";
    assert_screen "tty1-selected", 15;

    # init
    ttylogin;

    sleep 3;
    type_string "PS1=\$\n";    # set constant shell promt
    sleep 1;

    script_sudo "chown $username /dev/$serialdev";

    become_root;
}

sub test_flags() {
    return { 'important' => 1, 'milestone' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
