# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Start HA support server and check network connectivity
# Maintainer: Denis Zyuzin <dzyuzin@suse.com>

use base "basetest";
use strict;
use testapi;
use lockapi;
use mmapi;

sub run() {
    #    for my $clustername (split(/,/, get_var('CLUSTERNAME'))) {
    #        mutex_unlock("MUTEX_HA_" . $clustername . "_NODE1_WAIT");    #start node1 and node2 jobs
    #        mutex_unlock("MUTEX_HA_" . $clustername . "_NODE2_WAIT");
    #    }
    # wait for bootup
    assert_screen "tty1-selected", 600;
    type_string "root\n";
    assert_screen "password-prompt";
    type_string "susetesting\n";
    type_string "ip a\n";
    type_string "ip route\n";
    type_string "if `ip a | grep -q '172.16.0.1/28'`; then echo ip1_okay > /dev/$serialdev; fi\n";
    wait_serial("ip1_okay") || die "support server doesn't have IP1";
    type_string "if `ip a | grep -q '172.16.0.17/28'`; then echo ip2_okay > /dev/$serialdev; fi\n";
    wait_serial("ip2_okay") || die "support server doesn't have IP2";
    type_string
"if `dig \@localhost srv1.alpha.ha-test.qa.suse.de +short | grep -q 172.16.0.1`; then echo dns1_okay > /dev/$serialdev; fi\n";
    wait_serial("dns1_okay") || die "support server cannot resolve DNS1";
    type_string
"if `dig \@localhost srv1.bravo.ha-test.qa.suse.de +short | grep -q 172.16.0.17`; then echo dns2_okay > /dev/$serialdev; fi\n";
    wait_serial("dns2_okay") || die "support server cannot resolve DNS2";
    type_string "exit\n";
    wait_for_children;    #don't destroy support server while children are running
}

sub test_flags() {
    return {fatal => 1};
}

1;
# vim: set sw=4 et:
