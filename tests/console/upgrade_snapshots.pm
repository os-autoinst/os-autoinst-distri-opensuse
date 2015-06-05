use base "consoletest";
use testapi;

sub run() {
    become_root();
    script_run("snapper list | tee /dev/$serialdev");
    # Check if the snapshots called 'before upgrade' and 'after upgrade' are
    # there.
    wait_serial(qr/before upgrade.*(\n.*)+after upgrade/, 5);
}

sub test_flags() {
    return { 'important' => 1 };
}

1;
# vim: set sw=4 et:
