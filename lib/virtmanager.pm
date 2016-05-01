package virtmanager;
use testapi;
use strict;

our @ISA    = qw(Exporter);
our @EXPORT = qw(launch_virtmanager connection_details create_vnet create_new_pool create_new_volume clean_up_desktop create_netinterface delete_netinterface create_guest);


sub launch_virtmanager() {
    clean_up_desktop();
    # start a console
    # launch virt-manager in an xterm
    x11_start_program("xterm");
    wait_idle;
    type_string "virt-manager", 50;
    send_key "ret";
    wait_idle;
    type_password;
    send_key "ret";
    wait_idle;
    save_screenshot;
}

sub clean_up_desktop {
    # close all window on the desktop
    # used before any new launch of virt-manager
    # ugly way but works :)
    for (1 .. 10) {
        send_key "alt-f4";
    }
}


# got to a specific tab in connection details
sub connection_details {
    my ($tab) = @_;
    # connection details
    send_key "alt-e", 1;
    sleep 1;
    # be sure return has been done
    send_key "ret", 1;
    sleep 1;
    # send_key "ret";
    if (get_var("DESKTOP") !~ /icewm/) {
        assert_screen "virtman-sle12-gnome_details", 40;
    }
    else {
        assert_screen "virt-manager_details", 40;
    }
    # be sure to be on a tab
    for (1 .. 4) {
        send_key "tab";
        #sleep 1;
    }
    # need to send X "right" key to go to the correct tab
    # network interface = 3
    # storage = 2
    # Virtual networks = 1
    my $count = "";
    if ($tab eq "netinterface") {
        $count = 3;
    }
    elsif ($tab eq "storage") {
        $count = 2;
    }
    elsif ($tab eq "virtualnet") {
        $count = 1;
    }
    else {
    }
    for (1 .. $count) {
        send_key "right";
        sleep 1;
    }
}

sub delete_vnet {
    # very complex to handle
    # if started need to be stop before
    # UNTESTED FIXME
    my ($value) = @_;
    send_key "down";
    for (1 .. $value) {
        send_key "down";
    }
    # press the stop button
    for (1 .. 6) {
        send_key "spc";
    }
}

sub create_vnet {
    my $vnet = shift;
    # virt-manager should be closed to be sure
    # that we the process start from a clean interface (no previous steps)

    # got to "+"
    # i know assert_and_click could be used
    #    for (1 .. 6) {
    #	send_key "tab";
    #        #sleep 1;
    #   }
    #send_key "spc";
    assert_and_click "SLE12_virt-manager_vnet_plus";

    # step 1
    # go to text
    type_string $vnet->{name}, 30;
    save_screenshot;
    send_key "ret", 10;
    # step 2
    save_screenshot;
    # got to enable_ipv4
    send_key "tab", 1;
    if ($vnet->{ipv4}{active} eq "true") {
        send_key "tab";
        sleep 1;
        type_string $vnet->{ipv4}{network};
        send_key "tab";
        sleep 1;
        if ($vnet->{ipv4}{dhcpv4}{active} eq "true") {
            send_key "tab";
            type_string $vnet->{ipv4}{dhcpv4}{start};
            send_key "tab";
            type_string $vnet->{ipv4}{dhcpv4}{end};
        }
        else {
            # disable
            send_key "spc";
            sleep 1;
        }
        send_key "tab";
        if ($vnet->{ipv4}{staticrouteipv4}{active} eq "true") {
            send_key "spc";
            sleep 1;
            send_key "tab";
            type_string $vnet->{ipv4}{staticrouteipv4}{tonet};
            send_key "tab";
            type_string $vnet->{ipv4}{staticrouteipv4}{viagw};
            sleep 1;
        }
        # if not staticrouteipv4 we can go next
    }
    else {
        # disable IPV4
        send_key "spc", 10;
    }
    save_screenshot;
    send_key "alt-f", 10;
    # step 3
    if ($vnet->{ipv6}{active} eq "true") {
        send_key "tab";
        send_key "spc";
        sleep 1;
        send_key "tab";
        sleep 1;
        type_string $vnet->{ipv6}{network};
        send_key "tab";
        sleep 1;
        if ($vnet->{ipv6}{dhcpv6}{active} eq "true") {
            send_key "spc";
            sleep 1;
            send_key "tab";
            type_string $vnet->{ipv6}{dhcpv6}{start};
            send_key "tab";
            type_string $vnet->{ipv6}{dhcpv6}{end};
        }
        send_key "tab";
        if ($vnet->{ipv4}{staticrouteipv6}{active} eq "true") {
            send_key "spc";
            sleep 1;
            send_key "tab";
            type_string $vnet->{ipv6}{staticrouteipv6}{tonet};
            send_key "tab";
            type_string $vnet->{ipv6}{staticrouteipv6}{viagw};
        }
    }
    save_screenshot;
    send_key "alt-f", 1;
    # step 4
    if ($vnet->{vnet}{isolatedvnet}{active} eq "true") {
        send_key "alt-i";
        send_key "tab", 1;
    }
    elsif ($vnet->{vnet}{fwdphysical}{active} eq "true") {
        send_key "tab",  1;
        send_key "down", 1;
        send_key "tab",  1;
        # we only support ANY now
        if ($vnet->{vnet}{fwdphysical}{destination} eq "any") {
            # sending tab will go to "mode"
            send_key "tab";
        }
        if ($vnet->{vnet}{fwdphysical}{mode} eq "nat") {
            send_key "tab";
        }
        elsif ($vnet->{vnet}{fwdphysical}{mode} eq "routed") {
            send_key "down", 1;
        }
    }
    # go to enable ipv6 routing
    send_key "tab";
    if ($vnet->{vnet}{ipv6routing} eq "true") {
        send_key "spc";
    }
    save_screenshot;
    # go to next
    send_key "tab", 1;
    sleep 1;
    if ($vnet->{vnetl}{DNSdomainname} ne "") {
        type_string $vnet->{vnet}{DNSdomainname};
    }
    save_screenshot;
    # finish
    valid_step();
    # always close this windows to restart from scratch
    send_key "ctrl-w";
}

sub loop_down {
    my ($count) = @_;
    for (1 .. $count) { send_key "down"; }
}


sub valid_step {
    # quick function to valid a step
    # validate step with forward
    send_key "alt-f";
    sleep 1;
    # be sure that there is no error, or remove them from screen
    save_screenshot;
    for (1 .. 4) { send_key "esc"; }
    # maybe we need to close an error box ...
    send_key "alt-c";
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

    # got to the "+"
    for (1 .. 8) {
        send_key "tab";
        #sleep 1;
    }
    send_key "spc";
    # step 1
    type_string $pool->{name};
    send_key "tab";
    my $count = "";
    # step 2 will be done in the if after type selection
    if ($pool->{data}{type} eq "dir") {
        send_key "alt-f";
        type_string $pool->{data}{target_path};
        valid_step();
    }
    elsif ($pool->{data}{type} eq "disk") {
        loop_down("1");
        send_key "alt-f", 1;
        send_key "tab",   1;
        type_string $pool->{data}{target_path}, 50;
        send_key "tab", 1;
        send_key "tab", 1;
        type_string $pool->{data}{source_path}, 50;
        send_key "tab", 1;
        send_key "tab", 1;
        if ($pool->{data}{buildpool} eq "true") {
            send_key "spc", 1;
        }
        valid_step();
    }
    elsif ($pool->{data}{type} eq "fs") {
        loop_down("2");
        send_key "alt-f", 1;
        send_key "tab",   1;
        type_string $pool->{data}{target_path}, 50;
        send_key "tab", 1;
        send_key "tab", 1;
        type_string $pool->{data}{source_path}, 50;
        valid_step();
    }
    elsif ($pool->{data}{type} eq "gluster") {
        loop_down("3");
        # ! NOT SUPPORTED !
        send_key "alt-f";
    }
    elsif ($pool->{data}{type} eq "iscsi") {
        loop_down("4");
        send_key "alt-f", 1;
        send_key "tab",   1;
        type_string $pool->{data}{target_path};
        send_key "tab";
        send_key "tab", 1;
        type_string $pool->{data}{hostname}, 50;
        send_key "tab", 1;
        type_string $pool->{data}{IQNsource}, 50;
        send_key "tab", 1;
        if ($pool->{data}{initiator}{activate} eq "true") {
            send_key "spc";
            send_key "tab", 1;
            type_string $pool->{data}{initiator}{name};
        }
        valid_step();
    }
    elsif ($pool->{data}{type} eq "logical") {
        loop_down("5");
        send_key "alt-f", 1;
        send_key "tab",   1;
        type_string $pool->{data}{target_path}, 50;
        send_key "tab", 1;
        send_key "tab", 1;
        type_string $pool->{data}{source_path}, 50;
        send_key "tab", 1;
        send_key "tab", 1;
        if ($pool->{data}{buildpool} eq "true") {
            send_key "spc";
        }
        valid_step();
    }
    elsif ($pool->{data}{type} eq "mpath") {
        loop_down("6");
        send_key "alt-f", 1;
        send_key "tab",   1;
        type_string $pool->{data}{target_path}, 50;
        valid_step();
    }
    elsif ($pool->{data}{type} eq "netfs") {
        loop_down("7");
        send_key "alt-f", 1;
        send_key "tab",   1;
        type_string $pool->{data}{target_path}, 50;
        send_key "tab";
        send_key "tab", 1;
        type_string $pool->{data}{hostname}, 50;
        send_key "tab", 1;
        type_string $pool->{data}{source_path}, 50;
        valid_step();
    }
    elsif ($pool->{data}{type} eq "scsi") {
        loop_down("8");
        send_key "alt-f", 1;
        send_key "tab",   1;
        type_string $pool->{data}{target_path}, 50;
        send_key "tab", 1;
        send_key "tab", 1;
        type_string $pool->{data}{source_path}, 50;
        valid_step();
    }

    # always close this windows to restart from scratch
    send_key "ctrl-w";
}

sub create_new_volume {
    my $volume = shift;
    # pool; name ; format ; capacity

    # virt-manager UI is a nightmare, and people
    # working on it donest follow any rules.... they just
    # remove shortcut "like that", there is no policie or strategy
    # such a nice tool.....
    # create a new volume using shortcut
    if (get_var("ISO") =~ /SLE-12-SP1/) {
        assert_and_click "SLE12SP1_virt-manager_storage_plus";
    }
    else {
        # old version of virt-manager provide shortcut...
        send_key "alt-n", 1;
    }
    type_string $volume->{name}, 20;
    send_key "tab", 10;
    # default is qcow2 go to the upper selection
    for (1 .. 4) { send_key "up"; }
    # order is: qcow2, raw, cow, qcow, qed, vmdk, vpc, vdi
    # there is no cow format under SLE12SP1, so using an index=0
    # to start loop down in that case
    my $index = 0;
    my $index_down;
    if (get_var("ISO") !~ /SLE-12-SP1/) {
        $index++;
    }
    if ($volume->{format} eq "raw") {
        # raw is the first one
        print "nothing to do\n";
    }
    elsif ($volume->{format} eq "cow") {
        loop_down("1");
    }
    elsif ($volume->{format} eq "qcow") {
        $index_down = $index + 1;
        loop_down($index_down);
    }
    elsif ($volume->{format} eq "qcow2") {
        $index_down = $index + 2;
        loop_down($index_down);
        if ($volume->{backingstore} ne "") {
            send_key "tab", 10;
            send_key "spc", 10;
            send_key "tab", 10;
            type_string $volume->{backingstore}, 50;
        }
        else { send_key "tab", 1; }
    }
    elsif ($volume->{format} eq "qed") {
        $index_down = $index + 3;
        loop_down($index_down);
    }
    elsif ($volume->{format} eq "vmdk") {
        $index_down = $index + 4;
        loop_down($index_down);
    }
    elsif ($volume->{format} eq "vpc") {
        $index_down = $index + 5;
        loop_down($index_down);
    }
    elsif ($volume->{format} eq "vdi") {
        $index_down = $index + 6;
        loop_down($index_down);
    }
    send_key "tab", 1;
    type_string $volume->{maxcapacity}, 50;
    if ($volume->{format} ne "qcow2") {
        send_key "tab", 1;
        type_string $volume->{allocation};
    }
    # alt-f is used for format also! duplicate shortcut....
    send_key "alt-f", 4;
    #    send_key "alt-f", 4;
    #send_key "ret", 4;
    save_screenshot;
    # close error windows in case of....
    #send_key "alt-c", 1;
}

sub delete_netinterface {
    # FIXME: can only delete latest netinterface created
    launch_virtmanager();
    # go tab networkd interface
    connection_details("netinterface");
    # to start from a good place, go to menu and escape
    send_key "alt-f";
    send_key "esc";
    # lets go to an interface now
    send_key "tab";
    sleep 1;
    send_key "down";
    sleep 1;
    for (1 .. 7) { send_key "tab"; sleep 1; }
    send_key "spc";
    sleep 1;
    save_screenshot;
    send_key "alt-y";
    # close virt-manager
    send_key "ctrl-w";
}


sub create_netinterface {
    my $netif = shift;
    # go to the "+" button
    wait_idle;
    for (1 .. 7) {
        send_key "tab", 10;
    }
    # press it
    send_key "spc", 1;
    # step 1
    # be sure to be at the first value (bridge)
    wait_idle;
    for (1 .. 4) {
        send_key "up", 20;
    }
    if ($netif->{type} eq "bridge") {
        print "nothing to do\n";
    }
    elsif ($netif->{type} eq "bond") {
        loop_down("1");
    }
    elsif ($netif->{type} eq "ethernet") {
        loop_down("2");
    }
    elsif ($netif->{type} eq "vlan") {
        loop_down("3");
    }
    send_key "alt-f", 1;
    # step 2
    # there is no name for ethernet or vlan
    if ($netif->{type} ne "ethernet" && $netif->{type} ne "vlan") {
        send_key "tab";
        sleep 1;
        type_string $netif->{name}, 50;
    }
    send_key "tab", 1;
    if ($netif->{startmode} eq "none") {
        print "default choice\n";
    }
    elsif ($netif->{startmode} eq "onboot") {
        send_key "down", 1;
    }
    elsif ($netif->{startmode} eq "hotplug") {
        send_key "down";
        send_key "down", 1;
    }
    send_key "tab", 1;
    if ($netif->{activenow} eq "true") {
        send_key "spc", 1;
    }
    send_key "tab", 1;
    #go to IPsettings
    send_key "ret";
    sleep 1;
    if ($netif->{ipsetting}{copy}{active} eq "true") {
        # FIXME
        send_key "tab", 10;
        send_key "up",  10;
        send_key "alt-o";
        sleep 1;
    }
    elsif ($netif->{ipsetting}{manually}{active} eq "true") {
        # default selection
        if ($netif->{ipsetting}{manually}{ipv4}{mode} eq "dhcp") {
            # default is dhcp
            print "nothing to do\n";
        }
        elsif ($netif->{ipsetting}{manually}{ipv4}{mode} eq "static") {
            send_key "tab";
            sleep 1;
            send_key "tab";
            sleep 1;
            send_key "tab";
            send_key "down";
            sleep 1;
            send_key "tab";
            type_string $netif->{ipsetting}{manually}{ipv4}{address}, 50;
            send_key "tab";
            sleep 1;
            type_string $netif->{ipsetting}{manually}{ipv4}{gateway}, 50;
        }
        elsif ($netif->{ipsetting}{manually}{ipv4}{mode} eq "noconf") {
            send_key "tab";
            sleep 1;
            send_key "tab";
            sleep 1;
            send_key "down";
            sleep 1;
            send_key "down";
            sleep 1;
        }
        save_screenshot;
        send_key "alt-o";
        sleep 1;
    }
    # next step for ethernet is interface selection, there is no other conf
    if ($netif->{type} ne "ethernet") {
        send_key "tab", 10;
    }
    if ($netif->{type} eq "bridge") {
        send_key "ret", 10;
        type_string $netif->{ipsetting}{bridgesettings}{fwddelay}, 50;
        if ($netif->{ipsetting}{bridgesettings}{stp} eq "true") {
            send_key "tab";
            send_key "ret";
        }
        save_screenshot;
        send_key "alt-o", 1;
        sleep 1;
    }
    if ($netif->{type} eq "vlan") {
        type_string $netif->{vlantag}, 50;
    }
    if ($netif->{type} eq "bond") {
        # skip this for now
        # FIXME
        print "not yet implemented\n";
    }
    send_key "tab", 10;
    save_screenshot;
    if ($netif->{interface} eq "lo") {
        send_key "spc";
    }
    elsif ($netif->{interface} eq "other") {
        send_key "down";
        send_key "down";
        send_key "spc", 1;
    }
    send_key "alt-f", 30;
    if ($netif->{type} ne "vlan" && $netif->{type} ne "bond") {
        # bridge/ethernet can take time to be up; waiting 35sec more
        save_screenshot;
        sleep 35;
    }
    save_screenshot;
    # close error windows in case of....
    send_key "alt-c";
    send_key "esc";
}

sub create_guest {
    my $guest = shift;
    # create using virt-install
    send_key "alt-f";
    send_key "n", 10;
    # step 1: method
    if ($guest->{method} eq "cdrom") {
        print "nothing to do\n";
    }
    elsif ($guest->{method} eq "net") {
        loop_down("1");
    }
    elsif ($guest->{method} eq "pxe") {
        loop_down("2");
    }
    elsif ($guest->{method} eq "image") {
        loop_down("3");
    }
    save_screenshot;
    # go to step2
    send_key "alt-f";
    wait_idle;
    # step 2: media installation
    send_key "alt-f", 10;
    # step 3: Mem and CPU
    send_key "tab", 10;
    type_string $guest->{memory}, 50;
    send_key "tab", 10;
    type_string $guest->{cpu}, 50;
    save_screenshot;
    send_key "alt-f", 10;
    # step 4: storage
    send_key "alt-m", 10;
    send_key "alt-w", 10;

    my $newvolume = {
        name        => "guest",
        format      => "qcow2",
        maxcapacity => "2.2",
        allocation  => "2.0",
    };
    create_new_volume($newvolume);
    save_screenshot;
    # choose this volume and press alt-v
    #send_key "tab"; sleep 1;
    if (get_var("DESKTOP") !~ /icewm/) {
        assert_and_click "virtman-sle12-gnome_choose_volume";
    }
    else {
        assert_and_click "virtman_choose_volume";
    }
    # go to last step
    send_key "alt-f", 10;
    # step 5: last conf
    send_key "tab", 10;
    type_string $guest->{name}, 50;
    # be sure to be in "customize"
    send_key "tab", 10;
    if ($guest->{custom} eq "true") {
        send_key "alt-u";
    }
    # go to advanced
    send_key "tab";
    if ($guest->{advanced} eq "true") {
        send_key "spc";
        send_key "tab";
        # unselect and select FIXED MAC
        send_key "alt-m", 10;
        send_key "alt-m";
        send_key "tab";
        # enter custom mac
        type_string $guest->{netmac};
    }
    save_screenshot;
    send_key "alt-f";
    if ($guest->{custom} eq "true") {
        send_key "tab";
        send_key "tab";
        send_key "tab", 10;
        for (1 .. 11) {
            # parse all options
            send_key "down", 10;
        }
        save_screenshot;
        send_key "up";
        # add a new hardware
        send_key "alt-d";
        # add RNG
        for (1 .. 17) {
            send_key "down";
        }
        save_screenshot;
        send_key "alt-f";
        for (1 .. 3) {
            send_key "tab";
        }
    }
    # install begin
    assert_and_click "virtman_guest_begin_install";
}


1;
# vim: set sw=4 et:
