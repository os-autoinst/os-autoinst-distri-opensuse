use base "basetest";
use strict;
use testapi;


sub run() {
    my $self = shift;

    #ensure_installed("virt-manager");
    # workaround for bug: 
    # Bug 948366 - "pkcon install virt-manager" report it will remove 
    # the package if this command is run twice
    x11_start_program("xterm");
    become_root();
    script_run "zypper -n in virt-manager";
    # exit root, and be the default user
    type_string "exit\n";
    send_key "alt-f4";
    wait_idle;
}

1;
# vim: set sw=4 et:

