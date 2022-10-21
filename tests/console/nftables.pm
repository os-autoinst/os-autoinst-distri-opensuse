# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: nftables
# Summary: Test nftables with firewalld
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;

    # check nftables, stop iptables and start firewalld by need
    my $logs = "/tmp/log";

    # check that nftables has been already installed
    zypper_call('info nftables', log => 'zypper_info.log');
    assert_script_run("if systemctl is-active -q iptables; then systemctl stop iptables; fi");
    systemctl("restart firewalld");

    # create a customer rule 'tcp-mss-clamp'
    script_run('cat > tcp-mss-clamp <<EOF
#  nft list chain inet firewalld filter_FWDO_public_allow
table inet firewalld {
        chain filter_FWDO_public_allow {
                tcp flags syn tcp option maxseg size set rt mtu
        }
}

EOF
true');

    # run and check customer rule, add firewall rule and restart firewalld
    assert_script_run("nft flush ruleset");
    assert_script_run("nft -f tcp-mss-clamp");
    assert_script_run("nft list chain inet firewalld filter_FWDO_public_allow");
    assert_script_run("nft list tables");
    # create a firewall rule
    script_run('cat > firewall <<EOF
# IP/IPv6 Firewall rule
flush ruleset

table firewall {
  chain incoming {
    type filter hook input priority 0; policy drop;

    # established/related connections
    ct state established,related accept

    # loopback interface
    iifname lo accept

    # icmp
    icmp type echo-request accept

    # open tcp ports: sshd (22), httpd (80)
    tcp dport {ssh, http} accept
  }
}

table ip6 firewall {
  chain incoming {
    type filter hook input priority 0; policy drop;

    # established/related connections
    ct state established,related accept

    # invalid connections
    ct state invalid drop

    # loopback interface
    iifname lo accept

    # icmp
    # routers may also want: mld-listener-query, nd-router-solicit
    icmpv6 type {echo-request,nd-neighbor-solicit} accept

    # open tcp ports: sshd (22), httpd (80)
    tcp dport {ssh, http} accept
  }
}

EOF
true');

    assert_script_run("nft -f firewall");
    assert_script_run("systemctl restart firewalld && sleep 5");
    record_info 'firewalld, restarted and it is active.' if script_run '! systemctl is-active firewalld';

    # check firewall settings and save them to logs
    assert_script_run('echo -e "____ firewall services --zone=public ____\n" >> ' . $logs);
    assert_script_run("firewall-cmd --list-services --zone=public | grep -e dhcpv6-client ");
    assert_script_run("firewall-cmd --list-services --zone=public |& tee -a $logs ");

    # Upload logs
    upload_logs("$logs");
}

1;
