# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# All of cases is based on the reference:
# https://documentation.suse.com/sles/15-SP1/single-html/SLES-admin/#id-1.3.3.6.13.6.11
#
# Package: yast2-dns-server bind bind-libs
# Summary: Create DNS forwarder and DNS server, verify lookup.
#
# 1. Create a sub to handle command and verify it result
# 2. Create DNS forwarder
# 3. Create DNS server
# 4. Add, remove, show records
# 5. Reproduce bugs
# Maintainer: Tony Yuan <tyuan@suse.com>

package yast_dns_server;
use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use List::Util qw(all any);
use Utils::Systemd 'disable_and_stop_service';
use version_utils 'is_sle';

sub cmd_handle {
    my ($self, $cmd, $subcmd, %args) = @_;
    my $zop;
    my $op;
    foreach my $k (keys %args) {
        if ($k eq "zone") {
            $zop = "zone=$args{$k}";
            delete $args{$k};
            next;
        }
        $op .= " $k=$args{$k}";
    }
    assert_script_run("yast2 dns-server $cmd $subcmd $zop $op");
    validate_script_output("yast2 dns-server $cmd show $zop 2>&1", sub {
            my $output = $_;
            if ($subcmd eq "remove") {
                any { $output !~ m/\Q$_\E/; } values %args;
            }
            else {
                all { $output =~ m/\Q$_\E/i; } values %args;
    } });
}

sub bug1151130_softfail {
    my ($self, $cmd, $subcmd, $zone, %args) = @_;
    my $op = '';
    my $vrf;
    foreach my $k (keys %args) {
        $op .= " $k=$args{$k}";
    }
    $vrf = $1 if ($op =~ /.*=(.*)$/);
    assert_script_run("yast2 dns-server $cmd $subcmd zone=$zone $op");
    my $out = script_output("yast2 dns-server $cmd show zone=$zone 2>&1");
    record_soft_failure("bsc#1151135") unless $out =~ /\Q$vrf\E/;
}

sub run {
    my $self = shift;
    select_serial_terminal;
    zypper_call("in yast2-dns-server bind", exitcode => [0, 102, 103, 106]);
    zypper_call("in bind-libs", exitcode => [0, 102, 103, 106]) if is_sle('=12-SP2');
    #enables netconfig to always force a replace of modified file to avoid ncurse prompt.
    assert_script_run(qq(sed -i 's/NETCONFIG_FORCE_REPLACE="no"/NETCONFIG_FORCE_REPLACE="yes"/' /etc/sysconfig/network/config));

    #Forward server and test lookup
    my $opensuseip = script_output("dig www.opensuse.org +short", 300);
    $opensuseip =~ s/.*^(\d+\.\d+\.\d+\.\d+).*/$1/ms;
    $self->cmd_handle("forwarders", "add", ip => "10.0.2.3");
    #disable dnssec validation
    assert_script_run("sed -i 's/#dnssec-validation auto/dnssec-validation no/' /etc/named.conf");
    systemctl("start named.service");
    validate_script_output('dig @localhost www.opensuse.org +short', sub { /\Q$opensuseip\E/ }, timeout => 300);

    assert_script_run("sed -i 's/dnssec-validation no/#dnssec-validation auto/' /etc/named.conf");
    $self->cmd_handle("forwarders", "remove", ip => "10.0.2.3");
    record_soft_failure("bsc#1151138") if (systemctl("is-active named.service", ignore_failure => 1));

    # create zone and reverse zone
    $self->cmd_handle("zones", "add", name => "example.org", zonetype => "master");
    $self->cmd_handle("zones", "add", name => "100.168.192.in-addr.arpa", zonetype => "master");

    # Create host and test lookup
    $self->cmd_handle("host", "add", zone => "example.org", hostname => "host02.example.org.", ip => "192.168.100.4");
    systemctl("start named.service") if systemctl("is-active named.service", ignore_failure => 1);
    validate_script_output('dig @localhost host02.example.org +short', sub { /\Q192.168.100.4\E/ });
    validate_script_output('dig @localhost -x 192.168.100.4 +short', sub { /\Qhost02.example.org\E/ });
    $self->cmd_handle("host", "remove", zone => "example.org", hostname => "host02.example.org.", ip => "192.168.100.4");

    #logging
    $self->cmd_handle("logging", "set", destination => "file", maxsize => "100M", file => "/var/log/named.log", maxversions => "3");

    # soa
    $self->cmd_handle("soa", "set", zone => "example.org", serial => "2019090502", expiry => "2W", retry => "2H");

    # dns record
    #i.e. dnsrecord add zone=example.org query=example.org. type=MX value='10 mail01'
    $self->cmd_handle("dnsrecord", "add", zone => "example.org", query => "subdomain.example.org.", type => "NS", value => "ns1");    #delegated domain
    $self->cmd_handle("dnsrecord", "remove", zone => "example.org", query => "subdomain.example.org.", type => "NS", value => "ns1");
    $self->cmd_handle("dnsrecord", "add", zone => "example.org", query => "host1", type => "A", value => "192.168.100.3");    #host adress
    $self->cmd_handle("dnsrecord", "remove", zone => "example.org", query => "host1", type => "A", value => "192.168.100.3");

    $self->cmd_handle("dnsrecord", "add", zone => "100.168.192.in-addr.arpa", query => "123", type => "PTR", value => "host1");    ##PTR
    $self->cmd_handle("dnsrecord", "remove", zone => "100.168.192.in-addr.arpa", query => "123", type => "PTR", value => "host1");
    $self->cmd_handle("dnsrecord", "add", zone => "example.org", query => "ns6", type => "CNAME", value => "server6.anywhere.net.");    ##CNAME
    $self->cmd_handle("dnsrecord", "remove", zone => "example.org", query => "ns6", type => "CNAME", value => "server6.anywhere.net.");

    # mailserver, nameserver
    $self->bug1151130_softfail("mailserver", "add", "example.org", priority => "97", mx => "mx001");
    $self->bug1151130_softfail("nameserver", "add", "example.org", ns => "ns2.example.com.");

    #startup setting
    systemctl("stop named.service") unless systemctl("is-active named.service", ignore_failure => 1);
    assert_script_run("yast2 dns-server startup atboot");
    my $out = script_output("yast2 dns-server startup show 2>&1");
    record_soft_failure("bsc#1151130") unless $out =~ /enabled in the boot process/;    #sle15+ bug
    record_soft_failure("bsc#1151130") unless systemctl("is-active named.service", ignore_failure => 1);    #sle12sp4- bug
    assert_script_run("yast2 dns-server startup manual");

    #remove zone, stop service
    $self->cmd_handle("zones", "remove", name => "example.org", zonetype => "master");
    $self->cmd_handle("zones", "remove", name => "100.168.192.in-addr.arpa", zonetype => "master");
    disable_and_stop_service('named.service');
    assert_script_run(qq(sed -i 's/NETCONFIG_FORCE_REPLACE="yes"/NETCONFIG_FORCE_REPLACE="no"/' /etc/sysconfig/network/config));
}

1;
