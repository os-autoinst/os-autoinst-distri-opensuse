use base "consoletest";
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
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";
    script_run "zypper -n install curl; echo \"zypper-curl-\$?-\" > /dev/$serialdev";
    wait_serial "zypper-curl-0-";
    script_run "exit";

    save_screenshot;
    send_key "ctrl-l";

    script_run("curl -L -v " . autoinst_url . "/data > test.data; echo \"curl-\$?\" > /dev/$serialdev");
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
