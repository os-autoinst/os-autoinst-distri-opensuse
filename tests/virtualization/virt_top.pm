use base "x11test";
use strict;
use testapi;


sub run() {
    my $self = shift;
    ensure_installed("virt-top");
    x11_start_program("xterm");
    wait_idle;
    become_root;
    script_run "/usr/bin/virt-top";
    wait_idle;
    assert_screen "virtman-sle12sp1-gnome_virt-top";
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:

