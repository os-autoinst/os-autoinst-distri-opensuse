use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root;
    set_root_prompt();
    script_run("zypper lr -d; echo zypper-lr-\$? > /dev/$serialdev");
    wait_serial("zypper-lr-0") || die "zypper lr failed";
    save_screenshot;

    type_string "exit\n";
}

1;
# vim: set sw=4 et:
