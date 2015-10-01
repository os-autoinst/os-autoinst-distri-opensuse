use base "basetest";
use strict;
use testapi;


sub run() {
    my $self = shift;
    x11_start_program("xterm");
    wait_idle;
    send_key "alt-f10";
    become_root;
    script_run "yast2 virtualization";
    wait_idle;
    save_screenshot;
    assert_screen "virt-sle12sp1-gnome_yast_virtualization";
    send_key "alt-f4";
    # select everything
    send_key "alt-x"; # XEN Server
    send_key "e"; # Xen tools
    send_key "k"; # KVM Server
    send_key "v"; # KVM tools
    send_key "l"; # libvirt-lxc

    # launch the installation
    send_key "alt-a";
    assert_screen "virt-sle12sp1-gnome_yast_virtualization_graphics";
    # select yes
    send_key "alt-y";
    assert_screen "virt-sle12sp1-gnome_yast_virtualization_bridge";
    # select yes
    send_key "alt-y";
    assert_screen "virt-sle12sp1-gnome_yast_virtualization_OK";
    send_key "alt-o";
    # close the xterm
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:

