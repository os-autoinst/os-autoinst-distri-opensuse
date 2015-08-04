use base "consoletest";
use testapi;

sub run() {
    become_root();
    script_run("snapper list | tee /dev/$serialdev");
    # Check if the snapshot called 'after installation' is there
    wait_serial("after installation", 5);
    script_run("exit");
}

sub test_flags() {
    return { 'important' => 1 };
}

1;
# vim: set sw=4 et:
