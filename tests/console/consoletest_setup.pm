use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    wait_idle;
    # let's see how it looks at the beginning
    save_screenshot;

    # verify there is a text console on tty1
    send_key "ctrl-alt-f1";
    assert_screen "tty1-selected", 15;

    # init
    # log into text console
    send_key "ctrl-alt-f4";
    # we need to wait more than five seconds here to pass the idle timeout in
    # case the system is still booting (https://bugzilla.novell.com/show_bug.cgi?id=895602)
    assert_screen "tty4-selected", 10;
    assert_screen "text-login", 10;
    type_string "$username\n";
    sleep 2;
    assert_screen "password-prompt", 10;
    type_password;
    type_string "\n";
    sleep 3;
    type_string "PS1=\$\n";    # set constant shell promt
    sleep 1;

    become_root;
    script_run "chown $username /dev/$serialdev";

    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";
    script_run "exit";

    save_screenshot;
    send_key "ctrl-l";

    script_run("curl -L -v " . get_var('AUTOINSTURL') . "/data > test.data; echo \"curl-\$?\" > /dev/$serialdev");
    wait_serial("curl-0", 10) || die 'curl failed';
    script_run " cpio -id < test.data; echo \"cpio-\$?\"> /dev/$serialdev";
    wait_serial("cpio-0", 10) || die 'cpio failed';
    script_run "ls -al data";

    save_screenshot;
}

sub test_flags() {
    return { 'important' => 1, 'milestone' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
