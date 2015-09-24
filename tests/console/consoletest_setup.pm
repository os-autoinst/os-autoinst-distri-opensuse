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
    # Export the existing status of running tasks for future reference (fail would export it again)
    type_string "ps axf > /tmp/psaxf_consoletest_setup.log\n";
    upload_logs "/tmp/psaxf_consoletest_setup.log";
    save_screenshot;

    # Stop packagekit
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";
    # Installing a minimal system gives a pattern conflicting with anything not minimal
    # Let's uninstall 'the pattern' (no packages affected) in order to be able to install stuff
    script_run "zypper -n rm patterns-openSUSE-minimal_base-conflicts";
    # Install curl and tar in order to get the test data
    assert_script_run "zypper -n install curl tar";
    script_run "exit";

    save_screenshot;
    send_key "ctrl-l";

    if (get_var("CONNECT_PASSWORD")) {
        script_run("curl -L -v '" . autoinst_url . "/data?connect_password=" . get_var("CONNECT_PASSWORD") . "' > test.data; echo \"curl-\$?\" > /dev/$serialdev");
    } else {
        script_run("curl -L -v '" . autoinst_url . "/data > test.data; echo \"curl-\$?\" > /dev/$serialdev");
    }
    wait_serial("curl-0", 10) || die 'curl failed';
    script_run " cpio -id < test.data; echo \"cpio-\$?\"> /dev/$serialdev";
    wait_serial("cpio-0", 10) || die 'cpio failed';
    script_run "ls -al data";

    save_screenshot;
}

sub post_fail_hook() {
    my $self = shift;

    $self->export_logs();
}

sub test_flags() {
    return { 'important' => 1, 'milestone' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
