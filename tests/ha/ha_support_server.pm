use base "basetest";
use strict;
use testapi;
use lockapi;
use Time::HiRes qw(sleep);

sub run() {
    assert_screen "tty1-selected", 60;
    type_string "root\n";
    assert_screen "password-prompt", 10;
    type_string "susetesting\n";
    type_string "if `ip a | grep -q '172.16.0.1/28'`; then echo ip1_okay > /dev/$serialdev; fi\n";
    wait_serial("ip1_okay") || die "support server doesn't have IP1";
    type_string "if `ip a | grep -q '172.16.0.17/28'`; then echo ip2_okay > /dev/$serialdev; fi\n";
    wait_serial("ip2_okay") || die "support server doesn't have IP2";
    type_string "if `dig \@localhost srv1.alpha.ha-test.qa.suse.de +short | grep -q 172.16.0.1`; then echo dns1_okay > /dev/$serialdev; fi\n";
    wait_serial("dns1_okay") || die "support server cannot resolve DNS1";
    type_string "if `dig \@localhost srv1.bravo.ha-test.qa.suse.de +short | grep -q 172.16.0.17`; then echo dns2_okay > /dev/$serialdev; fi\n";
    wait_serial("dns2_okay") || die "support server cannot resolve DNS2";
    type_string "echo support server seems to be working, creating mutex\nexit\n";
    mutex_create "hacluster_support_server_ready";
    sleep 300000;
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
