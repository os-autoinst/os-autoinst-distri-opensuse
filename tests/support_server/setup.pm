# Copyright (C) 2015-2016 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

# Summary: supportserver and supportserver generator implementation
# Maintainer: Pavel Sladek <psladek@suse.com>

use strict;
use base 'basetest';
use lockapi;
use testapi;
use mm_network;

my $pxe_server_set  = 0;
my $quemu_proxy_set = 0;
my $http_server_set = 0;
my $ftp_server_set  = 0;
my $tftp_server_set = 0;
my $dns_server_set  = 0;
my $dhcp_server_set = 0;
my $nfs_mount_set   = 0;

my $setup_script;

my @mutexes;

sub setup_pxe_server {
    return if $pxe_server_set;

    $setup_script .= "curl -f -v " . autoinst_url . "/data/supportserver/pxe/setup_pxe.sh  > setup_pxe.sh\n";
    $setup_script .= "/bin/bash -ex setup_pxe.sh\n";

    $pxe_server_set = 1;
}


sub setup_http_server {
    return if $http_server_set;

    $setup_script .= "rcapache2 stop\n";
    $setup_script .= "curl -f -v " . autoinst_url . "/data/supportserver/http/apache2  >/etc/sysconfig/apache2\n";
    $setup_script .= "rcapache2 start\n";

    $http_server_set = 1;
}

sub setup_ftp_server {
    return if $ftp_server_set;

    $ftp_server_set = 1;
}

sub setup_tftp_server {
    return if $tftp_server_set;

    $setup_script .= "rcatftpd stop\n";
    $setup_script .= "rcatftpd start\n";

    $tftp_server_set = 1;
}

sub setup_networks {
    my $net_conf = parse_network_configuration();

    for my $network (keys %$net_conf) {
        my $server_ip = ip_in_subnet($net_conf->{$network}, 1);
        $setup_script .= "NIC=`grep $net_conf->{$network}->{mac} /sys/class/net/*/address |cut -d / -f 5`\n";
        $setup_script .= "cat > /etc/sysconfig/network/ifcfg-\$NIC <<EOT\n";
        $setup_script .= "IPADDR=$server_ip\n";
        $setup_script .= "NETMASK=$net_conf->{$network}->{subnet_mask}\n";
        $setup_script .= "STARTMODE='auto'\n";
        $setup_script .= "EOT\n";
    }
    $setup_script .= "rcnetwork restart\n";

    $setup_script .= "FIXED_NIC=`grep $net_conf->{fixed}->{mac} /sys/class/net/*/address |cut -d / -f 5`\n";
    $setup_script .= "iptables -t nat -A POSTROUTING -o \$FIXED_NIC -j MASQUERADE\n";
    for my $network (keys %$net_conf) {
        next if $network eq 'fixed';
        next unless $net_conf->{$network}->{gateway};
        "NIC=`grep $net_conf->{$network}->{mac} /sys/class/net/*/address |cut -d / -f 5`\n";
        $setup_script
          .= "iptables -A FORWARD -i \$FIXED_NIC -o \$NIC -m state  --state RELATED,ESTABLISHED -j ACCEPT\n";
        $setup_script .= "iptables -A FORWARD -i \$NIC -o \$FIXED_NIC -j ACCEPT\n";
    }
    $setup_script .= "echo 1 > /proc/sys/net/ipv4/ip_forward\n";
    $setup_script .= "ip route\n";
    $setup_script .= "ip addr\n";
    $setup_script .= "iptables -v -L\n";
}

sub setup_dns_server {
    return if $dns_server_set;
    $setup_script .= "
        sed -i -e 's|^NETCONFIG_DNS_FORWARDER=.*|NETCONFIG_DNS_FORWARDER=\"bind\"|' \\
               -e 's|^NETCONFIG_DNS_FORWARDER_FALLBACK=.*|NETCONFIG_DNS_FORWARDER_FALLBACK=\"no\"|' /etc/sysconfig/network/config
        sed -i -e 's|#forwarders.*;|include \"/etc/named.d/forwarders.conf\";|' /etc/named.conf
        sed -i -e 's|^NAMED_CONF_INCLUDE_FILES=.*|NAMED_CONF_INCLUDE_FILES=\"openqa.zones\"|' /etc/sysconfig/named

        curl -f -v " . autoinst_url . "/data/supportserver/named/openqa.zones > /etc/named.d/openqa.zones
        curl -f -v "
      . autoinst_url . "/data/supportserver/named/openqa.test.zone > /var/lib/named/master/openqa.test.zone
        curl -f -v "
      . autoinst_url
      . "/data/supportserver/named/2.0.10.in-addr.arpa.zone > /var/lib/named/master/2.0.10.in-addr.arpa.zone
        chown named:named /var/lib/named/master

        netconfig update -f
        rcnamed start
        rcnamed status
        rcdhcpd restart
    ";
    $dns_server_set = 1;
}


sub setup_dhcp_server {
    my ($dns) = @_;
    return if $dhcp_server_set;
    my $net_conf = parse_network_configuration();

    $setup_script .= "rcdhcpd stop\n";
    $setup_script .= "cat  >/etc/dhcpd.conf <<EOT\n";
    $setup_script .= "default-lease-time 14400;\n";
    if ($dns) {
        $setup_script .= "ddns-update-style standard;\n";
        $setup_script .= "ddns-updates on;\n";
        $setup_script .= "
        zone openqa.test. {
            primary 127.0.0.1;
        }
        zone 2.0.10.in-addr.arpa. {
            primary 127.0.0.1;
        }
        ";
    }
    else {
        $setup_script .= "ddns-update-style none;\n";
    }
    $setup_script .= "dhcp-cache-threshold 0;\n";
    $setup_script .= "\n";
    for my $network (keys %$net_conf) {
        next unless $net_conf->{$network}->{dhcp};
        my $server_ip = ip_in_subnet($net_conf->{$network}, 1);
        $setup_script .= "subnet $net_conf->{$network}->{subnet_ip} netmask $net_conf->{$network}->{subnet_mask} {\n";
        $setup_script
          .= "  range  "
          . ip_in_subnet($net_conf->{$network}, 15) . "  "
          . ip_in_subnet($net_conf->{$network}, 100) . ";\n";
        $setup_script .= "  default-lease-time 14400;\n";
        $setup_script .= "  max-lease-time 172800;\n";
        $setup_script .= "  option domain-name \"openqa.test\";\n";
        if ($dns) {
            $setup_script .= "  option domain-name-servers  $server_ip,  $server_ip;\n";
        }
        if ($net_conf->{$network}->{gateway}) {
            if ($network eq 'fixed') {
                $setup_script .= "  option routers 10.0.2.2;\n";
            }
            else {
                $setup_script .= "  option routers $server_ip;\n";
            }
        }
        $setup_script .= "  filename \"/boot/pxelinux.0\";\n";
        $setup_script .= "  next-server $server_ip;\n";
        $setup_script .= "}\n";
    }
    $setup_script .= "EOT\n";

    $setup_script
      .= "curl -f -v " . autoinst_url . "/data/supportserver/dhcp/sysconfig/dhcpd  >/etc/sysconfig/dhcpd \n";
    $setup_script .= "NIC_LIST=\"";
    for my $network (keys %$net_conf) {
        next unless $net_conf->{$network}->{dhcp};
        $setup_script .= "`grep $net_conf->{$network}->{mac} /sys/class/net/*/address |cut -d / -f 5` ";
    }
    $setup_script .= "\"\n";
    $setup_script .= 'sed -i -e "s|^DHCPD_INTERFACE=.*|DHCPD_INTERFACE=\"$NIC_LIST\"|" /etc/sysconfig/dhcpd' . "\n";

    $setup_script .= "rcdhcpd start\n";

    $dhcp_server_set = 1;
}



sub setup_nfs_mount {
    return if $nfs_mount_set;


    $nfs_mount_set = 1;
}


sub setup_aytests {
    # install the aytests-tests package and export the tests over http
    my $aytests_repo = get_var("AYTESTS_REPO");
    $setup_script .= "
    zypper -n --no-gpg-checks ar '$aytests_repo' aytests
    zypper -n --no-gpg-checks in aytests-tests

    curl -f -v " . autoinst_url . "/data/supportserver/aytests/aytests.conf >/etc/apache2/vhosts.d/aytests.conf
    curl -f -v " . autoinst_url . "/data/supportserver/aytests/aytests.cgi >/srv/www/cgi-bin/aytests
    chmod 755 /srv/www/cgi-bin/aytests

    cp -pr /var/lib/autoinstall/aytests /srv/www/htdocs/aytests
    rcapache2 restart
    ";
}


sub run {

    configure_default_gateway;
    configure_static_ip('10.0.2.1/24');
    configure_static_dns(get_host_resolv_conf());

    assert_script_run "ping -c 1 10.0.2.2 || journalctl -b --no-pager >/dev/$serialdev";

    my @server_roles = split(',|;', lc(get_var("SUPPORT_SERVER_ROLES")));
    my %server_roles = map { $_ => 1 } @server_roles;

    setup_networks();

    if (exists $server_roles{pxe}) {
        setup_dhcp_server((exists $server_roles{dns}));
        setup_pxe_server();
        setup_tftp_server();
        push @mutexes, 'pxe';
    }
    if (exists $server_roles{tftp}) {
        setup_tftp_server();
        push @mutexes, 'tftp';
    }

    if (exists $server_roles{dhcp}) {
        setup_dhcp_server((exists $server_roles{dns}));
        push @mutexes, 'dhcp';
    }
    if (exists $server_roles{qemuproxy}) {
        setup_http_server();
        $setup_script
          .= "curl -f -v "
          . autoinst_url
          . "/data/supportserver/proxy.conf | sed -e 's|#AUTOINST_URL#|"
          . autoinst_url
          . "|g' >/etc/apache2/vhosts.d/proxy.conf\n";
        $setup_script .= "rcapache2 restart\n";
        push @mutexes, 'qemuproxy';
    }
    if (exists $server_roles{dns}) {
        setup_dns_server();
        push @mutexes, 'dns';
    }

    if (exists $server_roles{aytests}) {
        setup_aytests();
        push @mutexes, 'aytests';
    }

    die "no services configured, SUPPORT_SERVER_ROLES variable missing?" unless $setup_script;

    print $setup_script;

    script_output($setup_script, 200);

    #create mutexes for running services
    foreach my $mutex (@mutexes) {
        mutex_create($mutex);
    }
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
