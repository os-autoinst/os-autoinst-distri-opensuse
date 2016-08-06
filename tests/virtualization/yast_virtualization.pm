use base "x11test";
use strict;
use testapi;

sub run() {
    my $self = shift;
    x11_start_program("xterm");
    wait_idle;
    send_key "alt-f10";
    become_root;
    script_run("/sbin/yast2 virtualization; echo yast2-virtualization-done-\$? > /dev/$serialdev", 0);
    assert_screen "virt-sle-gnome_yast_virtualization";
    if (check_var("FLAVOR", "Desktop-DVD")) {
        # select everything
        send_key "alt-v";    # Virtualization client tools
        send_key "alt-l";    # libvirt-lxc
    }
    else {
        # select everything
        send_key "alt-x";    # XEN Server
        send_key "alt-e";    # Xen tools
        send_key "alt-k";    # KVM Server
        send_key "alt-v";    # KVM tools
        send_key "alt-l";    # libvirt-lxc
    }

    # launch the installation
    send_key "alt-a";
    assert_screen "virt-sle12sp1-gnome_yast_virtualization_install_progress", 100;
    # answer question of installing graphics stuff
    #assert_screen "virt-sle12sp1-gnome_yast_virtualization_graphics", 100;
    # select yes
    #send_key "alt-y";
    if (get_var("STANDALONEVT")) {
        assert_screen "virt-sle12sp1-gnome_yast_virtualization_OK", 200;
    }
    if (check_screen("virt-sle12sp1-gnome_yast_virtualization_bridge", 120)) {
        # select yes
        send_key "alt-y";
    }

    assert_screen "virt-sle-gnome_yast_virtualization_installed", 60;
    send_key "alt-o";
    wait_serial("yast2-virtualization-done-0", 200) || die "yast2 virtualization failed";
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

sub test_flags() {
    return {important => 1, milestone => 1};
}

1;
# vim: set sw=4 et:

