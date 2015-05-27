use base "consoletest";
use testapi;

sub run() {
    my $self = shift;

    become_root();

    script_run("snapper list | tee /dev/$serialdev");
    # Check if the snapshot called 'after installation' is there
    $self->result('fail') unless wait_serial("after installation", 5);
    save_screenshot();
}

sub test_flags() {
    return { 'important' => 1 };
}

1;
# vim: set sw=4 et:
