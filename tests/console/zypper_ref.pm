use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;
    set_root_prompt();
    script_run("zypper ref; echo zypper-ref-\$? > /dev/$serialdev");
    # don't trust graphic driver repo
    if (check_screen("new-repo-need-key", 20)) {
        type_string "r\n";
    }
    wait_serial("zypper-ref-0") || die "zypper ref failed";
    assert_screen("zypper_ref");

    type_string "exit\n";
}

sub test_flags() {
    return {important => 1, milestone => 1,};
}

1;
# vim: set sw=4 et:
