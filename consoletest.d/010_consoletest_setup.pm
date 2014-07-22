use base "basetest";
use bmwqemu;

sub run() {
    my $self = shift;

    # init
    # log into text console
    send_key "ctrl-alt-f4";
    assert_screen "text-login", 10;
    type_string "$username\n";
    sleep 2;
    sendpassword;
    type_string "\n";
    sleep 3;
    type_string "PS1=\$\n";    # set constant shell promt
    sleep 1;

    #type_string 'PS1=\$\ '."\n"; # qemu-0.12.4 can not do backslash yet. http://permalink.gmane.org/gmane.comp.emulators.qemu/71856

    script_sudo("chown $username /dev/$serialdev");
    
    script_run("curl -v http://$vars{OPENQA_HOSTNAME}/tests/$vars{TEST_ID}/data > test.data; echo \"curl-\$?\" > /dev/$serialdev");
    wait_serial("curl-0", 10) || die 'curl failed';
    script_run(" cpio -id < test.data; echo \"cpio-\$?\"> /dev/$serialdev");
    wait_serial("cpio-0", 10) || die 'cpio failed';
    script_run("ls -al data");

    save_screenshot;
}

sub test_flags() {
    return { 'important' => 1, 'milestone' => 1, 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
