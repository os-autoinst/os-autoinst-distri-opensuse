use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    ensure_installed("virt-install");
    x11_start_program("xterm");
    wait_idle;
    become_root;
    script_run("virt-install --name TESTING --memory 512 --disk none --boot cdrom --graphics vnc &");
    x11_start_program("vncviewer :0");
    wait_idle;
    assert_screen "virtman-sle12sp1-gnome_virt-install", 100;
    for (0 .. 2) {
        send_key "alt-f4";
    }    # closing all windows
}

1;
# vim: set sw=4 et:

