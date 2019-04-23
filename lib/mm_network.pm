package mm_network;

use strict;
use warnings;

use base 'Exporter';
use Exporter;

use testapi;

our @EXPORT = qw(configure_hostname get_host_resolv_conf
  configure_static_ip configure_dhcp configure_default_gateway configure_static_dns
  parse_network_configuration ip_in_subnet check_ip_in_subnet setup_static_mm_network);

sub configure_hostname {
    my ($hostname) = @_;
    if (get_var('VERSION') =~ /^11/) {
        type_string "echo '$hostname' > /etc/HOSTNAME\n";
        type_string "echo '$hostname' > /etc/hostname\n";
        type_string "hostname '$hostname'\n";
    }
    else {
        type_string "hostnamectl set-hostname '$hostname'\n";
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

sub configure_static_ip {
    my ($ip, $mtu) = @_;
    my $net_conf = parse_network_configuration();
    my $mac      = $net_conf->{fixed}->{mac};
    $mtu //= 1458;
    script_run "NIC=`grep $mac /sys/class/net/*/address |cut -d / -f 5`";
    assert_script_run "echo \$NIC";
    my ($ip_no_mask, $mask) = split('/', $ip);
    script_run "arping -w 1 -I \$NIC $ip_no_mask";    # check for duplicate IP

    assert_script_run "echo \"STARTMODE='auto'\nBOOTPROTO='static'\nIPADDR='$ip'\nMTU='$mtu'\" > /etc/sysconfig/network/ifcfg-\$NIC";
    save_screenshot;
    assert_script_run "rcnetwork restart";
    assert_script_run "ip addr";
    save_screenshot;
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
    type_string("done\n");
    save_screenshot;
    assert_script_run "rcnetwork restart";
    assert_script_run "ip addr";
    save_screenshot;
}

sub configure_default_gateway {
    type_string("echo 'default 10.0.2.2 - -' > /etc/sysconfig/network/routes\n");
}

sub configure_static_dns {
    my ($conf) = @_;
    my $servers = join(" ", @{$conf->{nameserver}});
    script_run("sed -i -e 's|^NETCONFIG_DNS_STATIC_SERVERS=.*|NETCONFIG_DNS_STATIC_SERVERS=\"$servers\"|' /etc/sysconfig/network/config");
    script_run("netconfig -f update");
    script_run("cat /etc/resolv.conf");
}

sub parse_network_configuration {
    my @networks = ('fixed');
    @networks = split /\s*,\s*/, get_var("NETWORKS") if get_var("NETWORKS");
    my @mac      = split /\s*,\s*/, get_var("NICMAC");
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
    $net_conf->{fixed}->{subnet}  = '10.0.2.0/24';
    $net_conf->{fixed}->{dhcp}    = 'yes';
    $net_conf->{fixed}->{gateway} = '10.0.2.2';

    for my $net (values %$net_conf) {
        if ($net->{subnet}) {
            my ($ip, $mask) = split /\//, $net->{subnet};
            $net->{subnet_ip} = $ip;
            if ($mask =~ /^\d+$/) {
                my $n  = 0xffffffff << (32 - $mask);
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
    configure_default_gateway;
    configure_static_ip($ip);
    configure_static_dns(get_host_resolv_conf());
}

1;
