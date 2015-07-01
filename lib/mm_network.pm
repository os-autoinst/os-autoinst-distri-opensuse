#!/usr/bin/perl -w

package mm_network;

use strict;

use base 'Exporter';
use Exporter;

use testapi;

our @EXPORT = qw/get_host_resolv_conf configure_static_ip configure_default_gateway configure_static_dns/;

sub get_host_resolv_conf {
    my %conf;
    open(FH, '<', "/etc/resolv.conf");
    while (<FH>) {
        if (/^nameserver\s+([0-9.]+)\s*$/) {
            $conf{nameserver} //= [];
            push @{$conf{nameserver}}, $1;
        }
        if (/search\s+(.+)\s*$/) {
            $conf{search} = $1;
        }
    }
    return \%conf;
}

sub configure_static_ip {
    my ($ip) = @_;
    type_string "cd /proc/sys/net/ipv4/conf\n";
    type_string "for i in *[0-9]; do ";
    type_string("echo \"STARTMODE='auto'\nBOOTPROTO='static'\nIPADDR='$ip'\" > /etc/sysconfig/network/ifcfg-\$i;");
    type_string("done\n");
    wait_idle(20);
    save_screenshot;
    type_string("rcnetwork restart\n");
    type_string("ip addr\n");
    type_string("cd -\n");
    wait_idle(20);
    save_screenshot;
}

sub configure_default_gateway {
    type_string("echo 'default 10.0.2.2 - -' > /etc/sysconfig/network/routes\n");
}

sub configure_static_dns {
    my ($conf) = @_;
    my $servers = join(" ", @{$conf->{nameserver}});
    script_output("
    sed -i -e 's|^NETCONFIG_DNS_STATIC_SERVERS=.*|NETCONFIG_DNS_STATIC_SERVERS=\"$servers\"|' /etc/sysconfig/network/config
    rcnetwork restart
    cat /etc/resolv.conf
    ", 100);
}


1;

# vim: sw=4 et
