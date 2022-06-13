package virtmanager;
use testapi;
use strict;
use warnings;
use version_utils 'is_sle';

our @ISA = qw(Exporter);
our @EXPORT = qw(launch_virtmanager connection_details create_vnet create_new_pool
  create_new_volume create_netinterface delete_netinterface create_guest powercycle
  detect_login_screen select_guest close_guest establish_connection);


sub launch_virtmanager {
    x11_start_program('virt-manager', target_match => [qw(virt-manager virt-manager-auth)]);
    if (match_has_tag('virt-manager-auth')) {
        type_password;
        send_key 'ret';
        assert_screen 'virt-manager';
    }
}

# got to a specific tab in connection details
sub connection_details {
    my ($tab) = @_;
    # connection details
    wait_screen_change { send_key 'alt-e' };
    # be sure return has been done
    send_key 'ret';
    assert_screen 'virt-manager_details';
    # be sure to be on a tab
    send_key 'tab' for (1 .. 4);
    # need to send X 'right' key to go to the correct tab
    my %count = (
        virtualnet => 1,
        storage => 2,
        netinterface => 3,
    );
    send_key 'right' for (1 .. $count{$tab});
}

sub delete_vnet {
    # very complex to handle
    # if started need to be stop before
    # UNTESTED FIXME
    my ($value) = @_;
    send_key 'down';
    send_key 'down' for (1 .. $value);
    # press the stop button
    send_key 'spc' for (1 .. 6);
}

sub create_vnet {
    my $vnet = shift;
    # virt-manager should be closed to be sure
    # that we the process start from a clean interface (no previous steps)

    # got to '+'
    assert_and_click 'virt-manager_vnet_plus';

    # step 1
    # go to text
    type_string $vnet->{name};
    save_screenshot;
    send_key 'ret';
    # step 2
    save_screenshot;
    # got to enable_ipv4
    wait_screen_change { send_key 'tab' };
    if ($vnet->{ipv4}{active} eq 'true') {
        wait_screen_change { send_key 'tab' };
        type_string $vnet->{ipv4}{network};
        wait_screen_change { send_key 'tab' };
        if ($vnet->{ipv4}{dhcpv4}{active} eq 'true') {
            send_key 'tab';
            type_string $vnet->{ipv4}{dhcpv4}{start};
            send_key 'tab';
            type_string $vnet->{ipv4}{dhcpv4}{end};
        }
        else {
            # disable
            send_key 'spc';
        }
        send_key 'tab';
        if ($vnet->{ipv4}{staticrouteipv4}{active} eq 'true') {
            wait_screen_change { send_key 'spc' };
            send_key 'tab';
            type_string $vnet->{ipv4}{staticrouteipv4}{tonet};
            send_key 'tab';
            type_string $vnet->{ipv4}{staticrouteipv4}{viagw};
        }
        # if not staticrouteipv4 we can go next
    }
    else {
        # disable IPV4
        send_key 'spc';
    }
    save_screenshot;
    wait_screen_change { send_key 'alt-f' };
    # step 3
    if ($vnet->{ipv6}{active} eq 'true') {
        wait_screen_change { send_key 'tab' };
        wait_screen_change { send_key 'spc' };
        wait_screen_change { send_key 'tab' };
        type_string $vnet->{ipv6}{network};
        wait_screen_change { send_key 'tab' };
        if ($vnet->{ipv6}{dhcpv6}{active} eq 'true') {
            wait_screen_change { send_key 'spc' };
            send_key 'tab';
            type_string $vnet->{ipv6}{dhcpv6}{start};
            send_key 'tab';
            type_string $vnet->{ipv6}{dhcpv6}{end};
        }
        send_key 'tab';
        if ($vnet->{ipv4}{staticrouteipv6}{active} eq 'true') {
            wait_screen_change { send_key 'spc' };
            send_key 'tab';
            type_string $vnet->{ipv6}{staticrouteipv6}{tonet};
            send_key 'tab';
            type_string $vnet->{ipv6}{staticrouteipv6}{viagw};
        }
    }
    save_screenshot;
    wait_screen_change { send_key 'alt-f' };
    # step 4
    if ($vnet->{vnet}{isolatedvnet}{active} eq 'true') {
        send_key 'alt-i';
        send_key 'tab';
    }
    elsif ($vnet->{vnet}{fwdphysical}{active} eq 'true') {
        wait_screen_change { send_key 'tab' };
        wait_screen_change { send_key 'down' };
        wait_screen_change { send_key 'tab' };
        # we only support ANY now
        if ($vnet->{vnet}{fwdphysical}{destination} eq 'any') {
            # sending tab will go to 'mode'
            send_key 'tab';
        }
        if ($vnet->{vnet}{fwdphysical}{mode} eq 'nat') {
            send_key 'tab';
        }
        elsif ($vnet->{vnet}{fwdphysical}{mode} eq 'routed') {
            wait_screen_change { send_key 'down' };
        }
    }
    # go to enable ipv6 routing
    send_key 'tab';
    if ($vnet->{vnet}{ipv6routing} eq 'true') {
        send_key 'spc';
    }
    save_screenshot;
    # go to next
    wait_screen_change { send_key 'tab' };
    if ($vnet->{vnetl}{DNSdomainname} ne '') {
        type_string $vnet->{vnet}{DNSdomainname};
    }
    save_screenshot;
    # finish
    valid_step();
    # always close this windows to restart from scratch
    send_key 'ctrl-w';
}

sub loop_down {
    my ($count) = @_;
    send_key 'down' for (1 .. $count);
}


sub valid_step {
    # quick function to valid a step
    # validate step with forward
    wait_screen_change { send_key 'alt-f' };
    # be sure that there is no error, or remove them from screen
    save_screenshot;
    send_key 'esc' for (1 .. 4);
    # maybe we need to close an error box ...
    send_key 'alt-c';
}

sub create_new_pool {
    my $pool = shift;
    # dir; target path
    # disk: target path; source path ; build pool 1/0
    # fs: target path; source path
    # iscsi: target path (/dev/disk/by-path); hostname; source IQN; initiator IQN 1/0 -> value
    # logical: target path; source path ;  build pool 1/0
    # mpath: target path (/dev/mapper)
    # netfs:  target path; hostname; source path
    # scsi: target path (dev/disk/by-path); source path (host0)

    # got to the '+'
    send_key 'tab' for (1 .. 8);
    send_key 'spc';
    # step 1
    type_string $pool->{name};
    send_key 'tab';
    my $count = '';
    # step 2 will be done in the if after type selection
    if ($pool->{data}{type} eq 'dir') {
        send_key 'alt-f';
        type_string $pool->{data}{target_path};
        valid_step();
    }
    elsif ($pool->{data}{type} eq 'disk') {
        loop_down('1');
        wait_screen_change { send_key 'alt-f' };
        wait_screen_change { send_key 'tab' };
        type_string $pool->{data}{target_path};
        wait_screen_change { send_key 'tab' };
        wait_screen_change { send_key 'tab' };
        type_string $pool->{data}{source_path};
        wait_screen_change { send_key 'tab' };
        wait_screen_change { send_key 'tab' };
        if ($pool->{data}{buildpool} eq 'true') {
            wait_screen_change { send_key 'spc' };
        }
        valid_step();
    }
    elsif ($pool->{data}{type} eq 'fs') {
        loop_down('2');
        wait_screen_change { send_key 'alt-f' };
        wait_screen_change { send_key 'tab' };
        type_string $pool->{data}{target_path};
        wait_screen_change { send_key 'tab' };
        wait_screen_change { send_key 'tab' };
        type_string $pool->{data}{source_path};
        valid_step();
    }
    elsif ($pool->{data}{type} eq 'gluster') {
        loop_down('3');
        # ! NOT SUPPORTED !
        send_key 'alt-f';
    }
    elsif ($pool->{data}{type} eq 'iscsi') {
        loop_down('4');
        send_key 'alt-f';
        send_key 'tab';
        type_string $pool->{data}{target_path};
        send_key 'tab';
        send_key 'tab';
        type_string $pool->{data}{hostname};
        send_key 'tab';
        type_string $pool->{data}{IQNsource};
        send_key 'tab';
        if ($pool->{data}{initiator}{activate} eq 'true') {
            send_key 'spc';
            send_key 'tab';
            type_string $pool->{data}{initiator}{name};
        }
        valid_step();
    }
    elsif ($pool->{data}{type} eq 'logical') {
        loop_down('5');
        send_key 'alt-f';
        send_key 'tab';
        type_string $pool->{data}{target_path};
        send_key 'tab';
        send_key 'tab';
        type_string $pool->{data}{source_path};
        send_key 'tab';
        send_key 'tab';
        if ($pool->{data}{buildpool} eq 'true') {
            send_key 'spc';
        }
        valid_step();
    }
    elsif ($pool->{data}{type} eq 'mpath') {
        loop_down('6');
        send_key 'alt-f';
        send_key 'tab';
        type_string $pool->{data}{target_path};
        valid_step();
    }
    elsif ($pool->{data}{type} eq 'netfs') {
        loop_down('7');
        send_key 'alt-f';
        send_key 'tab';
        type_string $pool->{data}{target_path};
        send_key 'tab';
        send_key 'tab';
        type_string $pool->{data}{hostname};
        send_key 'tab';
        type_string $pool->{data}{source_path};
        valid_step();
    }
    elsif ($pool->{data}{type} eq 'scsi') {
        loop_down('8');
        send_key 'alt-f';
        send_key 'tab';
        type_string $pool->{data}{target_path};
        send_key 'tab';
        send_key 'tab';
        type_string $pool->{data}{source_path};
        valid_step();
    }

    # always close this windows to restart from scratch
    send_key 'ctrl-w';
}

sub create_new_volume {
    my $volume = shift;
    # pool; name ; format ; capacity

    # create a new volume using shortcut
    send_key 'alt-n';
    type_string $volume->{name};
    send_key 'tab';
    # default is qcow2 go to the upper selection
    send_key 'up' for (1 .. 4);
    # order is: qcow2, raw, cow, qcow, qed, vmdk, vpc, vdi
    my $index = 0;
    my $index_down;
    if ($volume->{format} eq 'raw') {
        # raw is the first one
        print "nothing to do\n";
    }
    elsif ($volume->{format} eq 'cow') {
        loop_down('1');
    }
    elsif ($volume->{format} eq 'qcow') {
        $index_down = $index + 1;
        loop_down($index_down);
    }
    elsif ($volume->{format} eq 'qcow2') {
        $index_down = $index + 2;
        loop_down($index_down);
        if ($volume->{backingstore} ne '') {
            send_key 'tab';
            send_key 'spc';
            send_key 'tab';
            type_string $volume->{backingstore};
        }
        else { send_key 'tab'; }
    }
    elsif ($volume->{format} eq 'qed') {
        $index_down = $index + 3;
        loop_down($index_down);
    }
    elsif ($volume->{format} eq 'vmdk') {
        $index_down = $index + 4;
        loop_down($index_down);
    }
    elsif ($volume->{format} eq 'vpc') {
        $index_down = $index + 5;
        loop_down($index_down);
    }
    elsif ($volume->{format} eq 'vdi') {
        $index_down = $index + 6;
        loop_down($index_down);
    }
    send_key 'tab';
    type_string $volume->{maxcapacity};
    if ($volume->{format} ne 'qcow2') {
        send_key 'tab';
        type_string $volume->{allocation};
    }
    # alt-f is used for format also! duplicate shortcut....
    send_key 'alt-f';
    save_screenshot;
}

sub delete_netinterface {
    # FIXME: can only delete latest netinterface created
    launch_virtmanager();
    # go tab networkd interface
    connection_details('netinterface');
    # to start from a good place, go to menu and escape
    send_key 'alt-f';
    send_key 'esc';
    # lets go to an interface now
    send_key 'tab';
    send_key 'down';
    send_key 'tab' for (1 .. 7);
    send_key 'spc';
    save_screenshot;
    send_key 'alt-y';
    # close virt-manager
    send_key 'ctrl-w';
}


sub create_netinterface {
    my $netif = shift;
    # go to the '+' button
    send_key 'tab' for (1 .. 7);
    # press it
    wait_screen_change { send_key 'spc' };
    # step 1
    # be sure to be at the first value (bridge)
    send_key 'up' for (1 .. 4);
    if ($netif->{type} eq 'bridge') {
        print "nothing to do\n";
    }
    elsif ($netif->{type} eq 'bond') {
        loop_down('1');
    }
    elsif ($netif->{type} eq 'ethernet') {
        loop_down('2');
    }
    elsif ($netif->{type} eq 'vlan') {
        loop_down('3');
    }
    send_key 'alt-f';
    # step 2
    # there is no name for ethernet or vlan
    if ($netif->{type} ne 'ethernet' && $netif->{type} ne 'vlan') {
        wait_screen_change { send_key 'tab' };
        type_string $netif->{name};
    }
    send_key 'tab';
    if ($netif->{startmode} eq 'none') {
        print "default choice\n";
    }
    elsif ($netif->{startmode} eq 'onboot') {
        send_key 'down';
    }
    elsif ($netif->{startmode} eq 'hotplug') {
        send_key 'down';
        send_key 'down';
    }
    send_key 'tab';
    if ($netif->{activenow} eq 'true') {
        send_key 'spc';
    }
    send_key 'tab';
    #go to IPsettings
    send_key 'ret';
    if ($netif->{ipsetting}{copy}{active} eq 'true') {
        send_key 'tab';
        send_key 'up';
        send_key 'alt-o';
    }
    elsif ($netif->{ipsetting}{manually}{active} eq 'true') {
        # default selection
        if ($netif->{ipsetting}{manually}{ipv4}{mode} eq 'dhcp') {
            # default is dhcp
            print "nothing to do\n";
        }
        elsif ($netif->{ipsetting}{manually}{ipv4}{mode} eq 'static') {
            send_key 'tab';
            send_key 'tab';
            send_key 'tab';
            send_key 'down';
            send_key 'tab';
            type_string $netif->{ipsetting}{manually}{ipv4}{address};
            send_key 'tab';
            type_string $netif->{ipsetting}{manually}{ipv4}{gateway};
        }
        elsif ($netif->{ipsetting}{manually}{ipv4}{mode} eq 'noconf') {
            send_key 'tab';
            send_key 'tab';
            send_key 'down';
            send_key 'down';
        }
        save_screenshot;
        send_key 'alt-o';
    }
    # next step for ethernet is interface selection, there is no other conf
    if ($netif->{type} ne 'ethernet') {
        send_key 'tab';
    }
    if ($netif->{type} eq 'bridge') {
        send_key 'ret';
        type_string $netif->{ipsetting}{bridgesettings}{fwddelay};
        if ($netif->{ipsetting}{bridgesettings}{stp} eq 'true') {
            send_key 'tab';
            send_key 'ret';
        }
        save_screenshot;
        send_key 'alt-o';
    }
    if ($netif->{type} eq 'vlan') {
        type_string $netif->{vlantag};
    }
    if ($netif->{type} eq 'bond') {
        # skip this for now
        # FIXME
        print "not yet implemented\n";
    }
    send_key 'tab';
    save_screenshot;
    if ($netif->{interface} eq 'lo') {
        send_key 'spc';
    }
    elsif ($netif->{interface} eq 'other') {
        send_key 'down';
        send_key 'down';
        send_key 'spc';
    }
    send_key 'alt-f';
    if ($netif->{type} ne 'vlan' && $netif->{type} ne 'bond') {
        # bridge/ethernet can take time to be up; waiting 35sec more
        save_screenshot;
        sleep 35;
    }
    save_screenshot;
    # close error windows in case of....
    send_key 'alt-c';
    send_key 'esc';
}

sub create_guest {
    my $guest = shift;
    # create using virt-install
    wait_screen_change { send_key 'alt-f' };
    send_key 'n';
    # step 1: method
    if ($guest->{method} eq 'cdrom') {
        print "nothing to do\n";
    }
    elsif ($guest->{method} eq 'net') {
        loop_down('1');
    }
    elsif ($guest->{method} eq 'pxe') {
        loop_down('2');
    }
    elsif ($guest->{method} eq 'image') {
        loop_down('3');
    }
    save_screenshot;
    # go to step2
    wait_screen_change { send_key 'alt-f' };
    # step 2: media installation
    send_key 'alt-f';
    # step 3: Mem and CPU
    send_key 'tab';
    type_string $guest->{memory};
    send_key 'tab';
    type_string $guest->{cpu};
    save_screenshot;
    send_key 'alt-f';
    # step 4: storage
    send_key 'alt-m';
    send_key 'alt-w';

    my $newvolume = {
        name => 'guest',
        format => 'qcow2',
        maxcapacity => '2.2',
        allocation => '2.0',
    };
    create_new_volume($newvolume);
    save_screenshot;
    # choose this volume and press alt-v
    assert_and_click 'virtman_choose_volume';
    # go to last step
    send_key 'alt-f';
    # step 5: last conf
    send_key 'tab';
    type_string $guest->{name};
    # be sure to be in "customize"
    send_key 'tab';
    send_key 'alt-u' if ($guest->{custom} eq 'true');
    # go to advanced
    send_key 'tab';
    if ($guest->{advanced} eq 'true') {
        send_key 'spc';
        send_key 'tab';
        # unselect and select FIXED MAC
        send_key 'alt-m';
        send_key 'alt-m';
        send_key 'tab';
        # enter custom mac
        type_string $guest->{netmac};
    }
    save_screenshot;
    send_key 'alt-f';
    if ($guest->{custom} eq 'true') {
        send_key 'tab';
        send_key 'tab';
        send_key 'tab';
        # parse all options
        send_key 'down' for (1 .. 11);
        save_screenshot;
        send_key 'up';
        # add a new hardware
        send_key 'alt-d';
        # add RNG
        send_key 'down' for (1 .. 17);
        save_screenshot;
        send_key 'alt-f';
        send_key 'tab' for (1 .. 3);
    }
    # install begin
    assert_and_click 'virtman_guest_begin_install';
}

# Expecting to see the guest screen
sub detect_login_screen {
    my $timeout = shift // 5;    # Can be increased f.e. if the guest is booting

    return if check_screen 'virt-manager_login-screen', $timeout;
    wait_still_screen 3;    # Connecting to guest's console
    mouse_set(30, 200);    # Go inside of the guest's console
    save_screenshot();
    mouse_set(300, 70);

    # esc, backspace
    return if check_screen 'virt-manager_login-screen', 5;
    send_key 'esc';
    send_key 'backspace';
    send_key 'backspace';

    # Escape from the guest's console
    mouse_set(0, 0);
    send_key "ctrl-alt";
    send_key "ctrl-alt";
    send_key 'esc';

    # ctrl+alt+f2
    return if check_screen 'virt-manager_login-screen', 5;
    assert_and_click 'virt-manager_send-key';
    assert_and_click 'virt-manager_ctrl-alt-f2';
    send_key 'ret';
    send_key 'ret';

    # esc, backspace
    return if check_screen 'virt-manager_login-screen', 5;
    send_key 'esc';
    send_key 'backspace';
    send_key 'backspace';

    # ctrl+alt+f3
    return if check_screen 'virt-manager_login-screen', 5;
    assert_and_click 'virt-manager_send-key';
    assert_and_click 'virt-manager_ctrl-alt-f3';
    send_key 'ret';
    send_key 'ret';

    # Reopen the guest window
    mouse_set(0, 0);
    assert_and_click 'virt-manager_file';
    mouse_set(0, 0);
    assert_and_click 'virt-manager_close';
    send_key 'ret';

    # ctrl+alt+f2
    return if check_screen 'virt-manager_login-screen', 5;
    assert_and_click 'virt-manager_send-key';
    assert_and_click 'virt-manager_ctrl-alt-f2';
    send_key 'ret';
    send_key 'ret';

    assert_screen "virt-manager_login-screen";
}

sub select_guest {
    my $guest = shift;
    send_key 'home';    # Go to top of the list
    assert_and_click "virt-manager_connected";
    wait_still_screen 3;    # Guests may be still loading
    if (!check_screen "virt-manager_list-$guest") {    # If the guest is hidden down in the list
        if (is_sle('12-SP2+') || check_var("REGRESSION", "qemu-hypervisor")) {
            send_key 'end';    # Go down so we will see every guest unselected on the way up
        } else {
            assert_and_click("virt-manager_list-arrowdown", clicktime => 10) for (1 .. 5);    # Go down so we will see every guest unselected on the way up
        }
        send_key_until_needlematch("virt-manager_list-$guest", 'up', 20, 3);
    }
    assert_and_click "virt-manager_list-$guest";
    send_key 'ret';
    sleep 5;
    if (check_screen 'virt-manager_notrunning') {
        record_info("The Guest was powered off and that should not happen");
        assert_and_click 'virt-manager_poweron', button => 'left', timeout => 90;
        sleep 30;    # The boot would not be faster
    }
    if (check_screen('virt-manager_no-graphical-device')) {
        wait_screen_change { send_key 'ctrl-q'; };
        send_key 'ret';
    }
}

sub close_guest {
    mouse_set(0, 0);
    assert_and_click 'virt-manager_file';
    mouse_set(0, 0);
    assert_and_click 'virt-manager_close';
}

sub powercycle {
    mouse_set(0, 0);
    assert_and_click 'virt-manager_shutdown';
    if (!check_screen 'virt-manager_notrunning', 120) {
        assert_and_click 'virt-manager_shutdown_menu';
        assert_and_click 'virt-manager_shutdown_item';
        # There might be a 'Are you sure' dialog window
        if (check_screen "virt-manager_shutdown_sure", 2) {
            assert_and_click "virt-manager_shutdown_sure";
        }
    }
    assert_and_click 'virt-manager_poweron', button => 'left', timeout => 90;
}

sub establish_connection {
    my $hypervisor = get_var('HYPERVISOR') // '127.0.0.1';

    assert_screen ['virt-manager_connected', 'virt-manager_not-connected', 'virt-manager_add-connection'], 30;
    if (match_has_tag 'virt-manager_add-connection') {
        if (check_var('REGRESSION', 'xen-client')) {
            send_key 'spc';
            send_key 'down';
            send_key 'down';
            send_key 'spc';
            wait_still_screen 1;    # XEN selected
        }
        send_key 'tab';
        send_key 'spc';
        wait_still_screen 1;    # Connect to remote host ticked
        send_key 'tab';
        send_key 'tab';
        type_string 'root';
        wait_still_screen 1;    # root written
        send_key 'tab';
        type_string "$hypervisor";
        wait_still_screen 1;    # $hypervisor written
        send_key 'tab';
        send_key 'spc';
        wait_still_screen 1;    # autoconnect ticked
        send_key 'ret';

        assert_screen "virt-manager_connected";
    }
    elsif (match_has_tag 'virt-manager_not-connected') {
        if (!check_screen("virt-manager_connected", 15)) {
            assert_and_dclick 'virt-manager_not-connected';
            assert_screen "virt-manager_connected";
        }
    }
}

1;
