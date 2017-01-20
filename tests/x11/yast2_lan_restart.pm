# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: YaST logic on Network Restart while no config changes were made
# Maintainer: Jozef Pupava <jpupava@suse.com>
# Tags: fate#318787 poo#11450

use base "x11test";
use strict;
use testapi;

sub run_yast2_lan {
    type_string "yast2 lan\n";
    assert_screen 'yast2_lan', 100;    # yast2 lan overview tab
}

sub run_yast2_lan_edit {
    run_yast2_lan;
    send_key 'alt-i';                  # Edit NIC
    assert_screen 'yast2_lan_network_card_setup';
}

sub close_yast {
    wait_still_screen;
    send_key 'alt-o';                  # OK
    if (check_screen 'yast2_lan_packages_need_to_be_installed', 5) {
        send_key 'alt-i';              # Install
    }
    assert_screen 'yast2_closed_xterm_visible', 120;
    script_run 'ip a';
    script_run '> strace.log';         # clear strace.log
}

sub check_network {
    my ($status) = @_;
    $status //= 'no_restart';
    wait_still_screen;
    send_key 'alt-o';                  # OK
    assert_screen 'yast2_closed_xterm_visible', 120;
    script_run 'ip a';
    if ("$status" eq 'restart') {
        assert_script_run '[ -s strace.log ]';    # strace.log size is greater than zero (network restarted)
    }
    else {
        script_run 'cat strace.log';                # print strace.log
        assert_script_run '[ ! -s strace.log ]';    # strace.log size is not greater than zero (network not restarted)
    }
    script_run "cat strace.log > /dev/$serialdev";    # print strace.log
    script_run '> strace.log';                        # clear strace.log
    type_string "\n\n";                               # make space for better readability of the console
}

sub add_device {
    my $device = shift;
    assert_screen 'yast2_closed_xterm_visible', 120;
    run_yast2_lan;
    if ("$device" eq 'bond') {
        send_key 'alt-i';                             # Edit NIC
        assert_screen 'yast2_lan_network_card_setup';
        send_key 'alt-k';                             # No link (Bonding Slavees)
        send_key 'alt-n';                             # Next
        assert_screen 'yast2_lan';                    # yast2 lan overview tab
    }
    send_key 'alt-a';                                 # Add NIC
    assert_screen 'yast2_lan_hardware_dialog';
    send_key 'alt-d';                                 # Device type
    send_key 'home';                                  # Jump to beginning of list
    send_key_until_needlematch "yast2_lan_device_type_$device", 'down';
    send_key 'alt-n';                                 # Next
    assert_screen 'yast2_lan_network_card_setup';
    send_key 'alt-y';                                 # Dynamic address
    wait_still_screen;
    if ("$device" eq 'bridge') {
        send_key 'alt-g';                             # General
        send_key 'alt-i';                             # Bridged devices
        assert_screen 'yast2_lan_bridged_devices';
        if (check_screen('yast2_lan_default_NIC_bridge')) {
            send_key 'alt-d';                         # select Bridged Devices region
            send_key 'spc';
            wait_still_screen;
            save_screenshot;
        }
        send_key 'alt-n';                             # Next
        assert_screen 'yast2_lan_select_already_configured_device';
        send_key 'alt-o';                             # OK
    }
    elsif ("$device" eq 'bond') {
        send_key 'alt-o';                             # Bond slaves
        assert_screen 'yast2_lan_bond_slaves';
        send_key_until_needlematch 'yast2_lan_bond_slave_tab_selected', 'tab';
        send_key 'tab';                               # select Bond Slaves and Order field
        send_key 'spc';                               # check network interface
        wait_still_screen;
        save_screenshot;
        send_key 'alt-n';                             # Next
    }
    elsif ("$device" eq 'VLAN') {
        send_key 'alt-v';
        send_key 'tab';
        type_string '12';
        send_key 'alt-n';                             # Next
    }
    else {
        send_key 'alt-n';                             # Next
    }
    close_yast;
}

sub select_special_device_tab {
    my $device = shift;
    run_yast2_lan;
    send_key 'tab';
    send_key 'tab';
    send_key 'home';
    send_key_until_needlematch "yast2_lan_device_${device}_selected", 'down';
    send_key 'alt-i';                                 # Edit NIC
    assert_screen 'yast2_lan_network_card_setup';
    if ("$device" eq 'bridge') {
        send_key 'alt-g';                             # General
        send_key 'alt-i';                             # Bridged devices
        assert_screen 'yast2_lan_bridged_devices';
    }
    elsif ("$device" eq 'bond') {
        send_key 'alt-o';                             # Bond slaves
        assert_screen 'yast2_lan_bond_slaves';
    }
    elsif ("$device" eq 'VLAN') {
        assert_screen 'yast2_lan_VLAN';
    }
    wait_still_screen;
    send_key 'alt-n';                                 # Next
}

sub del_device {
    my $device = shift;
    run_yast2_lan;
    send_key 'tab';
    send_key 'tab';
    send_key 'home';
    send_key_until_needlematch "yast2_lan_device_${device}_selected", 'down';
    send_key 'alt-t';                                 # Delete NIC
    wait_still_screen;
    save_screenshot;
    send_key 'alt-i';                                 # Edit NIC
    assert_screen 'yast2_lan_network_card_setup';
    send_key 'alt-y';                                 # Dynamic address
    send_key 'alt-n';                                 # Next
    close_yast;
}

sub test_2 {
    diag
'__________(2) Start yast2 lan -> Edit (a NIC) -> no change, don\'t switch to another tab, [Next] -> [OK]__________';
    run_yast2_lan_edit;
    send_key 'alt-n';                                 # Next
    check_network;
}

sub test_5 {
    diag '__________(5) Start yast2 lan -> Edit (a NIC) -> no change, switch to Hardware tab, [Next] -> [OK]__________';
    run_yast2_lan_edit;
    send_key 'alt-w';                                 # Hardware tab
    assert_screen 'yast2_lan_hardware_tab';
    send_key 'alt-n';                                 # Next
    check_network;
}

sub test_6 {
    diag '__________(6) Start yast2 lan -> Edit (a NIC) -> no change, switch to General tab, [Next] -> [OK]__________';
    run_yast2_lan_edit;
    send_key 'alt-g';                                 # General tab
    assert_screen 'yast2_lan_general_tab';
    send_key 'alt-n';                                 # Next
    check_network;
}

sub test_7 {
    my $dev_name = shift;
    diag
'__________(7) Start yast2 lan -> Edit (a NIC) -> switch to Hardware tab, change nic name, [Next] -> [OK] -> device name is changed__________';
    run_yast2_lan_edit;
    send_key 'alt-w';                                 # Hardware tab
    assert_screen 'yast2_lan_hardware_tab';
    send_key 'alt-e';                                 # Change device name
    assert_screen 'yast2_lan_device_name';
    send_key 'alt-m';                                 # Udev rule based on MAC
    send_key 'tab';
    send_key 'tab';
    send_key 'tab';
    send_key 'tab';
    type_string "$dev_name";
    send_key 'alt-o';                                 # OK
    send_key 'alt-n';                                 # Next
    check_network('restart');
}

sub run() {
    x11_start_program("xterm -geometry 155x50+5+5");
    become_root;
    type_string "strace -e trace=socket -p `pidof wickedd` -o strace.log &\n";
    send_key 'ret';
    script_run '> strace.log';                        # clear strace.log
    diag '__________(1) Start yast2 lan -> [OK]__________';
    type_string "# (1) NO restart\n";
    run_yast2_lan;
    check_network;
    type_string "# (2) NO restart\n";
    test_2;
    diag '__________(3) Start yast2 lan -> Go through all tabs -> no change anywhere -> [OK]__________';
    type_string "# (3) NO restart\n";
    run_yast2_lan;
    send_key 'alt-g';                                 # Global options tab
    assert_screen 'yast2_lan_global_options_tab';
    send_key 'alt-s';                                 # Hostname/DNS tab
    assert_screen 'yast2_lan_hostname_tab';
    send_key 'alt-u';                                 # Routing tab
    assert_screen 'yast2_lan_routing_tab';
    check_network;
    diag
'__________(4) Start yast2 lan -> Select routing tab -> change value in a default gw checkbox -> select another tab -> go back an change value in the checkbox back -> [OK]__________';
    type_string "# (4) NO restart\n";
    run_yast2_lan;
    send_key 'alt-u';                                 # Routing tab
    assert_screen 'yast2_lan_routing_tab';
    type_string '10.0.2.2';
    save_screenshot;
    send_key 'alt-g';                                 # Global options tab
    assert_screen 'yast2_lan_global_options_tab';
    send_key 'alt-u';                                 # Routing tab
    assert_screen 'yast2_lan_routing_tab';
    send_key 'backspace';                             # Delete selected IP
    check_network;
    type_string "# (5) NO restart\n";
    test_5;
    type_string "# (6) NO restart\n";
    test_6;
    type_string "# (7) restart\n";
    test_7('dyn0');
    diag '__________(8) check that "special" tabs works as well (brindge / bond slaves, wlan)__________';
    type_string "# (8) bridge NO restart\n";
    add_device('bridge');
    select_special_device_tab('bridge');
    check_network;
    del_device('bridge');
    type_string "# (8) bond NO restart\n";
    add_device('bond');
    select_special_device_tab('bond');
    check_network;
    del_device('bond');
    type_string "# (8) VLAN NO restart\n";
    add_device('VLAN');
    select_special_device_tab('VLAN');
    check_network;
    del_device('VLAN');
    diag '__________(10) Start yast2 lan -> Edit (a NIC) -> change from DHCP to static, [Next] -> [OK]__________';
    run_yast2_lan_edit;
    send_key 'alt-t';    # Static address
    send_key 'alt-i';    # Select IP field
    type_string '10.0.2.1';
    send_key 'tab';      # Subnet mask
    type_string '/24';
    send_key 'tab';      # Hostname
    type_string 'openqa';
    save_screenshot;
    send_key 'alt-n';    # Next
    wait_still_screen;
    send_key 'alt-s';    # Hostname/DNS tab
    assert_screen 'yast2_lan_hostname_tab';
    send_key 'alt-1';    # Name server 1
    type_string '10.100.2.88';
    wait_still_screen;
    save_screenshot;
    send_key 'alt-u';    # Routing tab
    assert_screen 'yast2_lan_routing_tab';
    type_string '10.0.2.2';
    wait_still_screen;
    save_screenshot;
    check_network('restart');
    diag '__________(9) checks described in (2), (5) - (7) static configuration__________';
    type_string "# (9.2) NO restart\n";
    test_2;
    type_string "# (9.5) NO restart\n";
    test_5;
    type_string "# (9.6) NO restart\n";
    test_6;
    type_string "# (9.7) restart\n";
    test_7('sta0');
    diag '__________(10) Start yast2 lan -> Edit (a NIC) -> change from static to DHCP, [Next] -> [OK]__________';
    type_string "# (10) restart\n";
    run_yast2_lan_edit;
    send_key 'alt-y';    # Dynamic address
    send_key 'alt-n';    # Next
    check_network('restart');
    type_string "killall xterm\n";
}

1;
# vim: set sw=4 et:
