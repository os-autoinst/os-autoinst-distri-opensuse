package mm_network;

use strict;
use warnings;

use base 'Exporter';
use Exporter;

use testapi;
use version_utils 'is_opensuse';

our @EXPORT = qw(configure_hostname get_host_resolv_conf is_networkmanager restart_networking
  configure_static_ip configure_dhcp configure_default_gateway configure_static_dns
  parse_network_configuration ip_in_subnet check_ip_in_subnet setup_static_mm_network);

sub configure_hostname {
    my ($hostname) = @_;
    if (get_var('VERSION') =~ /^11/) {
        enter_cmd "echo '$hostname' > /etc/HOSTNAME";
        enter_cmd "echo '$hostname' > /etc/hostname";
        enter_cmd "hostname '$hostname'";
    }
    else {
        enter_cmd "hostnamectl set-hostname '$hostname'";
    }
}

sub get_host_resolv_conf {
    my %conf;
    open(my $fh, '<', "/etc/resolv.conf");
    while (my $line = <$fh>) {
        if ($line =~ /^nameserver\s+([0-9.]+)\s*$/) {
            $conf{nameserver} //= [];
            push @{$conf{nameserver}}, $1;
        }
        if ($line =~ /search\s+(.+)\s*$/) {
            $conf{search} = $1;
        }
    }
    close($fh);
    return \%conf;
}

sub is_networkmanager {
    my $is_nm = (script_run('readlink /etc/systemd/system/network.service | grep NetworkManager') == 0);
    record_info('NetworkManager', (($is_nm) ? 'NetworkManager has been detected.' : 'NetworkManager has not been detected.'));
    return $is_nm;
}

sub configure_static_ip {
    my (%args) = @_;
    my $ip = $args{ip};
    my $mtu = $args{mtu} // 1458;
    my $is_nm = $args{is_nm} // is_networkmanager();
    my $device = $args{device};
    $mtu //= 1458;

    if ($is_nm) {
        my $nm_id;
        my $nm_list = script_output("nmcli -t -f DEVICE,NAME c | grep '$device' | head -n1");
        ($device, $nm_id) = split(':', $nm_list);

        record_info('set_ip', "Device: $device\n NM ID: $nm_id\nIP: $ip\nMTU: $mtu");

        assert_script_run "nmcli connection modify '$nm_id' ifname '$device' ip4 $ip ipv4.method manual 802-3-ethernet.mtu $mtu";
    } else {
        # Get MAC address
        my $net_conf = parse_network_configuration();
        my $mac = $net_conf->{fixed}->{mac};

        # Get default network adapter name
        $device = script_output("grep $mac /sys/class/net/*/address |cut -d / -f 5") unless ($device);
        record_info('set_ip', "Device: $device\nIP: $ip\nMTU: $mtu");

        # check for duplicate IP
        my ($ip_no_mask, $mask) = split('/', $ip);
        script_run "arping -w 1 -I $device $ip_no_mask";

        # Configure the static networking
        assert_script_run "echo -e \"STARTMODE='auto'\\nBOOTPROTO='static'\\nIPADDR='$ip'\\nMTU='$mtu'\" > /etc/sysconfig/network/ifcfg-$device";
    }
}

sub configure_dhcp {
    my $net_conf = parse_network_configuration();
    my @mac;
    for my $net (values %$net_conf) {
        push @mac, $net->{mac} if $net->{dhcp};
    }
    type_string "for MAC in " . join(' ', @mac) . " ; do ";
    type_string "NIC=`grep \$MAC /sys/class/net/*/address |cut -d / -f 5`;";
    type_string("echo \"STARTMODE='auto'\nBOOTPROTO='dhcp'\n\" > /etc/sysconfig/network/ifcfg-\$NIC;");
    enter_cmd 'done';
    save_screenshot;
    assert_script_run "rcnetwork restart";
    assert_script_run "ip addr";
    save_screenshot;
}

sub configure_default_gateway {
    my (%args) = @_;
    my $is_nm = $args{is_nm} // is_networkmanager();
    my $device = $args{device};
    if ($is_nm) {
        my $nm_id;
        # When $device is not specified grep just does nothing and first connection is selected
        my $nm_list = script_output("nmcli -t -f DEVICE,NAME c | grep '$device' | head -n1");
        ($device, $nm_id) = split(':', $nm_list);

        assert_script_run "nmcli connection modify '$nm_id' ipv4.gateway 10.0.2.2";
    } else {
        enter_cmd("echo 'default 10.0.2.2 - -' > /etc/sysconfig/network/routes");
    }
}

sub configure_static_dns {
    my ($conf, %args) = @_;
    my $is_nm = $args{is_nm} // is_networkmanager();
    my $nm_id = $args{nm_id};
    my $silent = $args{silent} // 0;

    my $servers = join(" ", @{$conf->{nameserver}});

    if ($is_nm) {
        $nm_id = script_output('nmcli -t -f NAME c | head -n 1') unless ($nm_id);

        assert_script_run "nmcli connection modify '$nm_id' ipv4.dns '$servers'";
    } else {
        assert_script_run("sed -i -e 's|^NETCONFIG_DNS_STATIC_SERVERS=.*|NETCONFIG_DNS_STATIC_SERVERS=\"$servers\"|' /etc/sysconfig/network/config");
        assert_script_run("netconfig -f update");
    }
}

sub parse_network_configuration {
    my @networks = ('fixed');
    @networks = split /\s*,\s*/, get_var("NETWORKS") if get_var("NETWORKS");
    my @mac = split /\s*,\s*/, get_var("NICMAC");
    my $net_conf = {};

    for (my $i = 0; $networks[$i]; $i++) {
        my $network = $networks[$i];
        $net_conf->{$network} = {
            mac => $mac[$i],
            num => $i,
        };
    }

    for (my $i = 0; $i < 10; $i++) {
        my $conf = get_var("NETWORK$i");
        if ($conf) {
            my ($network, @param) = split /\s*,\s*/, $conf;
            if (!defined $net_conf->{$network}) {
                print "unknown network $network\n";
                next;
            }
            for my $p (@param) {
                my ($name, $val) = split /=/, $p;
                $net_conf->{$network}->{$name} = $val;
            }
        }
    }

    $net_conf->{fixed} //= {};
    $net_conf->{fixed}->{subnet} = '10.0.2.0/24';
    $net_conf->{fixed}->{dhcp} = 'yes';
    $net_conf->{fixed}->{gateway} = '10.0.2.2';

    for my $net (values %$net_conf) {
        if ($net->{subnet}) {
            my ($ip, $mask) = split /\//, $net->{subnet};
            $net->{subnet_ip} = $ip;
            if ($mask =~ /^\d+$/) {
                my $n = 0xffffffff << (32 - $mask);
                my $n4 = $n % 256;
                $n /= 256;
                my $n3 = $n % 256;
                $n /= 256;
                my $n2 = $n % 256;
                $n /= 256;
                my $n1 = $n % 256;

                $mask = "$n1.$n2.$n3.$n4";
            }
            $net->{subnet_mask} = $mask;
        }
    }
    return $net_conf;
}
sub ip_in_subnet {
    my ($network, $num) = @_;
    my ($i1, $i2, $i3, $i4) = split /\./, $network->{subnet_ip};
    my $ip = ((($i1 * 256) + $i2) * 256 + $i3) * 256 + $i4 + $num;
    my $n4 = $ip % 256;
    $ip /= 256;
    my $n3 = $ip % 256;
    $ip /= 256;
    my $n2 = $ip % 256;
    $ip /= 256;
    my $n1 = $ip % 256;
    return join '.', ($n1, $n2, $n3, $n4);
}

sub check_ip_in_subnet {
    my ($network, $ip) = @_;

    my ($i1, $i2, $i3, $i4) = split /\./, $network->{subnet_ip};
    my $subnet_ip = ((($i1 * 256) + $i2) * 256 + $i3) * 256 + $i4;

    ($i1, $i2, $i3, $i4) = split /\./, $network->{subnet_mask};
    my $mask_ip = ((($i1 * 256) + $i2) * 256 + $i3) * 256 + $i4;

    ($i1, $i2, $i3, $i4) = split /\./, $ip;
    my $check_ip = ((($i1 * 256) + $i2) * 256 + $i3) * 256 + $i4;

    return ($check_ip & $mask_ip) == ($subnet_ip & $mask_ip);
}

sub setup_static_mm_network {
    my $ip = shift;
    my $is_nm = is_networkmanager();
    configure_static_ip(ip => $ip, is_nm => $is_nm);
    configure_default_gateway(is_nm => $is_nm);
    configure_static_dns(get_host_resolv_conf(), is_nm => $is_nm);
    restart_networking(is_nm => $is_nm);
}

sub restart_networking {
    my (%args) = @_;
    my $is_nm = $args{is_nm} // is_networkmanager();

    if ($is_nm) {
        assert_script_run 'nmcli networking off';
        assert_script_run 'nmcli networking on';
        # Wait until the connections are configured
        assert_script_run 'nmcli networking connectivity check';
    } else {
        assert_script_run 'rcnetwork restart';
    }

    record_info('network cfg', script_output('ip address show; echo; ip route show; echo; grep -v "^#" /etc/resolv.conf', proceed_on_failure => 1));
}

1;
