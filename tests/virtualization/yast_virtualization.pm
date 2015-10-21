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
    assert_screen "virt-sle12sp1-gnome_yast_virtualization", 50;
    # select everything
    send_key "alt-x", 10; # XEN Server
    send_key "alt-e", 10; # Xen tools
    send_key "alt-k", 10; # KVM Server
    send_key "alt-v", 10; # KVM tools
    send_key "alt-l", 10; # libvirt-lxc

    # launch the installation
    send_key "alt-a";
    assert_screen "virt-sle12sp1-gnome_yast_virtualization_install_progress", 100;
    # answer question of installing graphics stuff
    #assert_screen "virt-sle12sp1-gnome_yast_virtualization_graphics", 100;
    # select yes
    #send_key "alt-y";
    if (get_var("STANDALONEVT")) {
	assert_screen "virt-sle12sp1-gnome_yast_virtualization_OK", 200;
    } else {
	assert_screen "virt-sle12sp1-gnome_yast_virtualization_bridge", 200;
	# select yes
	send_key "alt-y";
    }
    send_key "alt-o";
    # close the xterm
    send_key "alt-f4";
    # now need to start libvirtd
    x11_start_program("xterm");
    send_key "alt-f10";
    wait_idle;
    become_root;
    type_string "systemctl start libvirtd", 50;
    send_key "ret";
    wait_idle;
    type_string "systemctl status libvirtd", 50;
    send_key "ret";
    save_screenshot;
    assert_screen "virt-sle12sp1-gnome_libvirtd_status", 20;
    # close the xterm
    send_key "alt-f4";
}

1;
# vim: set sw=4 et:

