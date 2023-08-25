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
    assert_script_run('curl -v -o tcp-mss-clamp ' .
          data_url('console/nftables/tcp-mss-clamp'));

    # run and check customer rule, add firewall rule and restart firewalld
    assert_script_run("nft flush ruleset");
    assert_script_run("nft -f tcp-mss-clamp");
    assert_script_run("nft list chain inet firewalld filter_FWDO_public_allow");
    assert_script_run("nft list tables");
    # create a firewall rule
    assert_script_run('curl -v -o firewall ' .
          data_url('console/nftables/firewall'));
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
