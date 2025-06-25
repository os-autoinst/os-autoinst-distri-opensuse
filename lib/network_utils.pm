=head1 network_utils

Functional methods to operate on network

=cut
# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Functional methods to operate on network
# Maintainer: Anton Smorodskyi <asmorodskyi@suse.com>
package network_utils;

use base Exporter;
use Exporter;

use strict;
use warnings;
use testapi;
use mm_network;
use Utils::Systemd qw(systemctl);

use utils qw(validate_script_output_retry);

our @EXPORT = qw(
  setup_static_network
  recover_network
  can_upload_logs
  iface
  ifc_exists
  ifc_is_up
  genmac
  cidr_to_netmask
  set_nics_link_speed_duplex
  check_connectivity_to_host_with_retry
  get_nics
  is_nm_used
  is_wicked_used
  delete_all_existing_connections
  create_bond
  add_interfaces_to_bond
  set_resolv
  set_nic_dhcp_auto_nmcli
  set_nic_dhcp_auto_wicked
  set_nic_dhcp_auto
  all_nics_have_ip
  reload_connections_until_all_ips_assigned
  setup_dhcp_server_network
);

=head2 setup_static_network

 setup_static_network(ip => '10.0.2.15', gw => '10.0.2.1');

Configure static IP on SUT with setting up default GW.
Also doing test ping to 10.0.2.2 to check that network is alive
Set DNS server defined via required variable C<STATIC_DNS_SERVER>

=cut

sub setup_static_network {
    my (%args) = @_;
    my $ip = $args{ip} // '10.0.2.15';
    my $mtu = $args{mtu} // get_var('MM_MTU', 1380);
    my $gw = $args{gw} // testapi::host_ip();

    configure_static_dns(get_host_resolv_conf(), silent => $args{silent} // 0);
    assert_script_run("echo default $gw - - > /etc/sysconfig/network/routes");
    my $iface = iface();
    assert_script_run qq(echo -e "\\nSTARTMODE='auto'\\nBOOTPROTO='static'\\nIPADDR='$ip'\\nMTU='$mtu'">/etc/sysconfig/network/ifcfg-$iface);
    assert_script_run 'rcnetwork restart';
    assert_script_run 'ip addr';
    assert_script_run "ping -c 1 $gw", fail_message => 'Gateway is not reachable, please check your network configuration and setups';
    assert_script_run "ip -6 addr add $args{ipv6} dev $iface" if exists $args{ipv6};
}

=head2 iface

 iface([$quantity]);

Return first NIC which is not loopback

=cut

sub iface {
    my ($quantity) = @_;
    $quantity ||= 1;
    # bonding_masters showing up in ppc64le jobs in 15-SP5: bsc#1210641
    return script_output('ls /sys/class/net/ | grep -v lo | grep -v bonding_masters | head -' . $quantity);
}

=head2 can_upload_logs

 can_upload_logs([$gw]);

Returns if can ping worker host gateway
=cut

sub can_upload_logs {
    my ($gw) = @_;
    $gw ||= testapi::host_ip();
    return (script_run('ping -c 1 ' . $gw) == 0);
}


=head2 recover_network

 recover_network([ip => $ip] [, gw => $gw]);

Recover network with static config if is feasible, returns if can ping GW.
Main use case is post_fail_hook, to be able to upload logs.

Accepts following parameters :

C<ip> => allowing to specify certain IP which would be used for recovery
in case skiped '10.0.2.15/24' will be used as fallback.

C<gw> => allowing to specify default gateway. Fallback to worker IP in case nothing specified.
=cut

sub recover_network {
    my (%args) = @_;

    # We set static setup just to upload logs, so no permament setup
    # Set default values
    $args{ip} //= '10.0.2.15/24';
    $args{gw} //= testapi::host_ip();
    my $iface = iface();
    # Clean routes and ip address settings
    script_run "ip a flush dev $iface";
    script_run 'ip r flush all';
    # Set expected ip and routes and set interface up
    script_run "ip a a $args{ip} dev $iface";
    script_run "ip r a default via $args{gw} dev $iface";
    script_run "ip link set dev $iface up";
    # Display settings
    script_run 'ip a s';
    script_run 'ip r s';

    return can_upload_logs();
}

=head2 ifc_exists

 ifc_exists([$ifc]);

Return if ifconfig exists.

=cut

sub ifc_exists {
    my ($ifc) = @_;
    return !script_run('ip link show dev ' . $ifc);
}

=head2 ifc_is_up

 ifc_is_up([$ifc]);

Return only if network status is UP.

=cut

sub ifc_is_up {
    my ($ifc) = @_;
    return !script_run("ip link show dev $ifc | grep 'state UP'");
}

=head2 genmac

Generate custom MAC address.
Used for Xen domU testing, to define MAC address once for whole test suite lifecycle.

 genmac(['aa:bb:cc'])

=cut

sub genmac {
    my @mac = split(/:/, shift);
    my $len = scalar(@mac);
    for (my $i = 0; $i < (6 - $len); $i++) {
        push @mac, (sprintf("%02X", int(rand(254))));
    }
    return lc(join(':', @mac));
}

=head2 cidr_to_netmask

Converts CIDR notation to a netmask string in IPv4 address format.

=cut

sub cidr_to_netmask {
    my ($cidr_str) = @_;

    $cidr_str =~ /(\d+)/;
    my $cidr = $1;

    my $binmask = '1' x $cidr . '0' x (32 - $cidr);
    my @octets = unpack("C4", pack("B32", $binmask));
    return join('.', @octets);
}

=head2 set_nics_link_speed_duplex

Sets the link speed, duplex settings, and autoneg status for specified NICs.
Accepts hash reference containing NICs and their settings.

  set_nics_link_speed_duplex({
    nics => ['eth0', 'eth1'],
    speed => 1000,       # Speed in Mbps
    duplex => 'full',    # Duplex type: 'full' or 'half'
    autoneg => 'off'     # Auto-negotiation: 'on' or 'off'
  });

=cut

sub set_nics_link_speed_duplex {
    my ($args_ref) = @_;
    my @nics = @{$args_ref->{nics}};
    my $speed = $args_ref->{speed} // 1000;    # default speed 1000 Mbps if not specified
    my $duplex = $args_ref->{duplex} // 'full';    # default to full duplex if not specified
    my $autoneg = $args_ref->{autoneg} // 'off';    # default to autoneg off if not specified

    for my $nic (@nics) {
        record_info("SET $nic", "Setting link speed to $speed, duplex to $duplex, and autoneg to $autoneg");
        script_run("ethtool -s $nic speed $speed duplex $duplex autoneg $autoneg");
    }
}

=head2 check_connectivity_to_host_with_retry

Checks connectivity from a specified bonding interface to a host.

This function pings a designated host from a specified bonding interface. It uses the function 
validate_script_output_retry to retry the ping command multiple times.

  check_connectivity_to_host_with_retry('bond0', '192.168.1.1');

=cut

sub check_connectivity_to_host_with_retry {
    my ($iface, $ping_host) = @_;
    my $ping_command = "ping -c1 -I $iface $ping_host";

    validate_script_output_retry(
        $ping_command,
        sub { m/1 packets transmitted, 1 received, 0% packet loss,/ },
        type_command => 1
    );
}

=head2 get_nics

Retrieves a list of network interfaces, excluding specified ones and the loopback interface.

This function scans for network interfaces available on the system, optionally ignoring specified interfaces
and always excluding the loopback interface. It's particularly useful for scripts that need to dynamically
determine which network interfaces to operate on, allowing for exclusion of interfaces that are not of interest.

  get_nics(['bond0', 'bond1']);

=cut

sub get_nics {
    my ($ignore_ref) = @_;
    my @ignore = @$ignore_ref;

    my $command = "ip -o link show | grep -v 'lo'";

    foreach my $iface (@ignore) {
        $command .= " | grep -v '$iface'";
    }

    $command .= " | awk -F: '{print \$2}' | awk '{print \$1}'";

    my $result = script_output($command, type_command => 1);

    my @nics = split(/\n/, $result);

    record_info(scalar(@nics) . " NICs Detected", join(', ', @nics));

    return @nics;
}

=head2 is_nm_used

 Check if NetworkManager service is active.

=cut

sub is_nm_used {
    return script_run("systemctl is-active NetworkManager") == 0;
}

=head2 is_wicked_used

 Check if wicked service is active.

=cut

sub is_wicked_used {
    return script_run("systemctl is-active wicked") == 0;
}

sub delete_all_existing_connections_nm {
    my $output = script_output('nmcli -g DEVICE,UUID conn show', type_command => 1);
    my %seen_uuids;

    foreach my $line (split "\n", $output) {
        next if $line =~ /^\s*$/;

        my ($device, $uuid) = split /:/, $line;
        next if defined $device && $device eq 'lo';
        next if exists $seen_uuids{$uuid};

        $seen_uuids{$uuid} = 1;
        assert_script_run "nmcli con delete uuid '$uuid'";
    }
}

sub delete_all_existing_connections_wicked {
    assert_script_run "wicked ifdown all";
    script_run "rm -f /etc/sysconfig/network/ifcfg-*";
}

sub delete_all_existing_connections {
    delete_all_existing_connections_nm() if is_nm_used();
    delete_all_existing_connections_wicked() if is_wicked_used();
}

sub create_bond {
    my ($bond_name, $options) = @_;
    my $bond_mode = $options->{mode};
    my $miimon = $options->{miimon} // 200;
    my $autoconnect_slaves = $options->{autoconnect_slaves} // 1;

    if (is_nm_used()) {
        assert_script_run "nmcli con add type bond ifname $bond_name con-name $bond_name bond.options \"mode=$bond_mode, miimon=$miimon\"";
        assert_script_run "nmcli connection modify $bond_name connection.autoconnect-slaves $autoconnect_slaves";
    }

    if (is_wicked_used()) {
        # Remove the old configuration file if it exists
        script_run "rm -f /etc/sysconfig/network/ifcfg-$bond_name";

        assert_script_run "echo 'STARTMODE=auto' > /etc/sysconfig/network/ifcfg-$bond_name";
        assert_script_run "echo 'BONDING_MASTER=yes' >> /etc/sysconfig/network/ifcfg-$bond_name";
        assert_script_run "echo 'BONDING_SLAVE=no' >> /etc/sysconfig/network/ifcfg-$bond_name";
        assert_script_run "echo 'BONDING_MODULE_OPTS=\"mode=$bond_mode miimon=$miimon\"' >> /etc/sysconfig/network/ifcfg-$bond_name";
    }
}

sub add_interfaces_to_bond {
    my ($bond_name, @interfaces) = @_;
    if (is_nm_used()) {
        foreach my $interface (@interfaces) {
            assert_script_run "nmcli con add type ethernet ifname $interface master $bond_name";
        }
    }

    if (is_wicked_used()) {
        my $index = 1;

        foreach my $interface (@interfaces) {
            # Remove the old configuration file for the interface if it exists
            script_run "rm -f /etc/sysconfig/network/ifcfg-$interface";

            # Create the new configuration file for the interface
            assert_script_run "echo 'BOOTPROTO=static' > /etc/sysconfig/network/ifcfg-$interface";
            assert_script_run "echo 'STARTMODE=auto' >> /etc/sysconfig/network/ifcfg-$interface";
            assert_script_run "echo 'BONDING_MASTER=no' >> /etc/sysconfig/network/ifcfg-$interface";
            assert_script_run "echo 'BONDING_SLAVE=yes' >> /etc/sysconfig/network/ifcfg-$interface";
            assert_script_run "echo 'BONDING_MASTER_IF=$bond_name' >> /etc/sysconfig/network/ifcfg-$interface";

            # Append slave interfaces to the bond configuration
            assert_script_run "echo 'BONDING_SLAVE_$index=$interface' >> /etc/sysconfig/network/ifcfg-$bond_name";
            $index++;
        }
    }
}

sub set_resolv {
    my (%args) = @_;
    $args{attempt_all_ns} //= 0;
    my @nameservers = @{$args{nameservers}};

    # Set DNS in /etc/resolv.conf
    assert_script_run("rm /etc/resolv.conf || true");
    assert_script_run("touch /etc/resolv.conf");

    foreach my $nameserver (@nameservers) {
        assert_script_run("echo 'nameserver $nameserver' >> /etc/resolv.conf");
    }

    if ($args{attempt_all_ns}) {
        # Set options
        assert_script_run("echo 'options rotate' >> /etc/resolv.conf");
        assert_script_run("echo 'options timeout:2' >> /etc/resolv.conf");

        # Set attempts based on the number of nameservers
        my $attempts_count = scalar @nameservers;    # Count the number of items in @nameservers
        assert_script_run("echo 'options attempts:$attempts_count' >> /etc/resolv.conf");
    }
}

sub set_nic_dhcp_auto_nmcli {
    my ($nic) = @_;
    assert_script_run "nmcli con add type ethernet ifname $nic con-name $nic";
    assert_script_run "nmcli con modify $nic ipv4.method auto connection.autoconnect yes";
}

sub set_nic_dhcp_auto_wicked {
    my ($nic) = @_;
    assert_script_run "echo 'BOOTPROTO=dhcp' > /etc/sysconfig/network/ifcfg-$nic";
    assert_script_run "echo 'STARTMODE=auto' >> /etc/sysconfig/network/ifcfg-$nic";
}

sub set_nic_dhcp_auto {
    my ($nic) = @_;
    set_nic_dhcp_auto_nmcli($nic) if is_nm_used();
    set_nic_dhcp_auto_wicked($nic) if is_wicked_used();
}

sub all_nics_have_ip {
    my ($nics_ref) = @_;
    my @nics = @$nics_ref;

    foreach my $nic (@nics) {
        my $ip_output = script_output("ip addr show $nic");
        if ($ip_output !~ /inet\s+\d+\.\d+\.\d+\.\d+/) {
            return 0;    # If any NIC doesn't have an IP, return false
        }
    }
    return 1;    # All NICs have an IP
}

sub reload_connections_until_all_ips_assigned {
    my (%args) = @_;
    $args{timeout} //= 180;
    $args{retry_interval} //= 10;

    my @nics = @{$args{nics}};

    my $reload_dhcp_fn = sub {
        die 'Incompatible network manager';
    };

    if (is_nm_used()) {
        $reload_dhcp_fn = sub {
            foreach my $nic (@nics) {
                assert_script_run "nmcli con down $nic || true";
                assert_script_run "nmcli con up $nic";
            }
        };
    } elsif (is_wicked_used()) {
        $reload_dhcp_fn = sub {
            systemctl 'restart wicked';
        };
    }

    # If a custom reload function is provided, use it
    if ($args{reload_dhcp_fn}) {
        $reload_dhcp_fn = $args{reload_dhcp_fn};
    }

    my $elapsed_time = 0;

    while ($elapsed_time < $args{timeout}) {
        $reload_dhcp_fn->();    # Execute the provided action (e.g., restart service)

        # Check if all NICs have an IP
        if (all_nics_have_ip(\@nics)) {
            last;    # All NICs have IP addresses, exit loop
        }

        sleep $args{retry_interval};
        $elapsed_time += $args{retry_interval};

        if ($elapsed_time >= $args{timeout}) {
            die "Failed to obtain IPs for all interfaces within $args{timeout} seconds";
        }
    }
}

sub setup_dhcp_server_network {
    my (%args) = @_;

    my $server_ip = $args{server_ip} // '10.0.2.101';
    my $subnet = $args{subnet} // '/24';
    my $gateway = $args{gateway} // '10.0.2.2';
    my @nics = @{$args{nics}};

    my $nic0 = $nics[0];

    record_info("SETUP_SERVER_NETWORK");

    # Bring down all non-loopback interfaces except the first one
    foreach my $nic (@nics[1 .. $#nics]) {
        record_info("Non-loopback interface $nic detected, bringing it down...");
        assert_script_run("ip link set $nic down");
    }

    delete_all_existing_connections();

    my $netmask = cidr_to_netmask($subnet);

    if (is_nm_used()) {
        assert_script_run "nmcli con add type ethernet ifname $nic0 con-name $nic0";
        assert_script_run "nmcli con modify $nic0 ipv4.addresses ${server_ip}${subnet} ipv4.gateway $gateway ipv4.routes '0.0.0.0/0 $gateway' ipv4.method manual";
        assert_script_run "nmcli con modify $nic0 connection.autoconnect yes";
        assert_script_run "nmcli con up $nic0";
    }

    if (is_wicked_used()) {
        my $ifcfg_file = "/etc/sysconfig/network/ifcfg-$nic0";
        my $route_file = "/etc/sysconfig/network/ifroute-$nic0";

        assert_script_run "echo 'BOOTPROTO=static' > $ifcfg_file";
        assert_script_run "echo 'STARTMODE=auto' >> $ifcfg_file";
        assert_script_run "echo 'IPADDR=$server_ip' >> $ifcfg_file";
        assert_script_run "echo 'GATEWAY=$gateway' >> $ifcfg_file";
        assert_script_run "echo 'NETMASK=$netmask' >> $ifcfg_file";

        script_run "rm -f $route_file";
        assert_script_run "echo 'default $gateway dev $nic0' > $route_file";

        systemctl 'restart wicked';
    }
}

1;
