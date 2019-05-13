# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test FirewallD basic usage
# Maintainer: Alexandre Makoto Tanno <atanno@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils 'systemctl';
use version_utils 'is_tumbleweed';

# Check Service State, enable it if necessary, set default zone to public
sub pre_test {
    record_info 'Check Service State';
    assert_script_run("if ! systemctl is-active -q firewalld; then systemctl start firewalld; fi");
    assert_script_run("firewall-cmd --set-default-zone=public");
}

# Test #1 - Stop firewalld then start it
sub test1 {
    record_info 'Test #1', 'Test: Stop firewalld, then start it';
    systemctl('stop firewalld');
    systemctl('start firewalld');

    # Check Service State, enable it if necessary
    record_info 'Check Service State';
    assert_script_run("if ! systemctl is-active -q firewalld | grep -q -i 'inactive'; then systemctl start firewalld; fi");
}

# Test #2 - Temporary Rules
sub test2 {
    record_info 'Test #2', 'Test Temporary Rules';
    script_run("iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules.txt");

    # Check if it's tumbleweed or Leap/SLE and run the correct test accordingly
    if (is_tumbleweed) {
        assert_script_run("firewall-cmd --zone=public --add-port=25/tcp");
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW,UNTRACKED -j ACCEPT");

        assert_script_run("firewall-cmd --zone=public --add-service=pop3");
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 110 -m conntrack --ctstate NEW,UNTRACKED -j ACCEPT");

        assert_script_run("firewall-cmd --zone=public --add-protocol=icmp");
        assert_script_run("iptables -C IN_public_allow -p icmp -m conntrack --ctstate NEW,UNTRACKED -j ACCEPT");

        assert_script_run("firewall-cmd --zone=public --add-port=2000-3000/udp");
        assert_script_run("iptables -C IN_public_allow -p udp --dport 2000:3000 -m conntrack --ctstate NEW,UNTRACKED -j ACCEPT");
    }
    else {
        assert_script_run("firewall-cmd --zone=public --add-port=25/tcp");
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW -j ACCEPT");

        assert_script_run("firewall-cmd --zone=public --add-service=pop3");
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 110 -m conntrack --ctstate NEW -j ACCEPT");

        assert_script_run("firewall-cmd --zone=public --add-protocol=icmp");
        assert_script_run("iptables -C IN_public_allow -p icmp -m conntrack --ctstate NEW -j ACCEPT");

        assert_script_run("firewall-cmd --zone=public --add-port=2000-3000/udp");
        assert_script_run("iptables -C IN_public_allow -p udp --dport 2000:3000 -m conntrack --ctstate NEW -j ACCEPT");
    }

    # Reload default configuration
    record_info 'Reload default configuration';
    assert_script_run("firewall-cmd --reload");
    assert_script_run("if [ `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules.txt` ]; then /usr/bin/true; else /usr/bin/false; fi");
}

# Test #3 - Test Permanent Rules
sub test3 {
    # Test Permanent Rules
    record_info 'Test #3', 'Test Permanent Rules';
    script_run("iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules.txt");

    assert_script_run("firewall-cmd --zone=public --permanent --add-port=25/tcp");
    assert_script_run("firewall-cmd --zone=public --permanent --add-service=pop3");
    assert_script_run("firewall-cmd --zone=public --permanent --add-protocol=icmp");
    assert_script_run("firewall-cmd --zone=public --permanent --add-port=2000-3000/udp");

    assert_script_run("firewall-cmd --reload");

    # Check if it's tumbleweed or Leap/SLE and run the correct test accordingly
    if (is_tumbleweed) {
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW,UNTRACKED -j ACCEPT");
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 110 -m conntrack --ctstate NEW,UNTRACKED -j ACCEPT");
        assert_script_run("iptables -C IN_public_allow -p icmp -m conntrack --ctstate NEW,UNTRACKED -j ACCEPT");
        assert_script_run("iptables -C IN_public_allow -p udp --dport 2000:3000 -m conntrack --ctstate NEW,UNTRACKED -j ACCEPT");
    }
    else {
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW -j ACCEPT");
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 110 -m conntrack --ctstate NEW -j ACCEPT");
        assert_script_run("iptables -C IN_public_allow -p icmp -m conntrack --ctstate NEW -j ACCEPT");
        assert_script_run("iptables -C IN_public_allow -p udp --dport 2000:3000 -m conntrack --ctstate NEW -j ACCEPT");
    }

    # Remove rules used in the test and reload default configuration
    record_info 'Remove rules and reload default configuration';
    assert_script_run("firewall-cmd --zone=public --permanent --remove-port=25/tcp");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-service=pop3");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-protocol=icmp");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-port=2000-3000/udp");
    assert_script_run("firewall-cmd --reload");
    assert_script_run("if [ `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules.txt`  ]; then /usr/bin/true; else /usr/bin/false; fi");

}

# Test #4 - Test Rules using Masquerading
sub test4 {
    record_info 'Test #4', 'Test Rules using Masquerading';
    script_run("iptables -t mangle -L PRE_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules_mangle.txt");
    script_run("iptables -t nat -L PRE_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules_nat.txt");


    assert_script_run("firewall-cmd --zone=public --add-masquerade");
    assert_script_run("firewall-cmd --zone=public --add-forward-port=port=2222:proto=tcp:toport=22");
    assert_script_run("iptables -t mangle -C PRE_public_allow -p tcp --dport 2222 -j MARK --set-mark `iptables -t mangle -L PRE_public_allow | grep -i MARK | sed 's/set /\$ /' | cut -f 2 -d \"\$\"`");
    assert_script_run("iptables -t nat -C PRE_public_allow -p tcp -m mark --mark `iptables -t mangle -L PRE_public_allow | grep -i MARK | sed 's/set /\$ /' | cut -f 2 -d \"\$\"` -j DNAT --to :22");

    # Reload default configuration
    record_info 'Reload default configuration';
    assert_script_run("firewall-cmd --reload");
    assert_script_run("if [ `iptables -t mangle -L PRE_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules_mangle.txt`  ]; then /usr/bin/true; else /usr/bin/false; fi");
    assert_script_run("if [ `iptables -t nat -L PRE_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules_nat.txt`  ]; then /usr/bin/true; else /usr/bin/false; fi");
}

# Test #5 - Test ipv4 family addresses with rich rules
sub test5 {
    record_info 'Test #5", "Test ipv4 family addresses with rich rules';
    script_run("iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules_allow.txt");
    script_run("iptables -L IN_public_deny --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules_deny.txt");

    assert_script_run("firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=\"ipv4\" source address=192.168.200.0/24 accept'");
    assert_script_run("firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=\"ipv4\" source address=192.168.201.0/24 drop'");
    assert_script_run("firewall-cmd --reload");
    assert_script_run("iptables -C IN_public_allow -s 192.168.200.0/24 -j ACCEPT");
    assert_script_run("iptables -C IN_public_deny -s 192.168.201.0/24 -j DROP");

    # Reload default configuration and flush rules
    record_info 'Remove rules used during the test and reload default configuration';
    assert_script_run("firewall-cmd --zone=public --permanent --remove-rich-rule 'rule family=\"ipv4\" source address=192.168.200.0/24 accept'");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-rich-rule 'rule family=\"ipv4\" source address=192.168.201.0/24 drop'");
    assert_script_run("firewall-cmd --reload");
    assert_script_run("if [ `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules_allow.txt`  ]; then /usr/bin/true; else /usr/bin/false; fi");
    assert_script_run("if [ `iptables -L IN_public_deny --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules_deny.txt`  ]; then /usr/bin/true; else /usr/bin/false; fi");
}

# Test #6 - Change the default zone
sub test6 {
    record_info 'Test #6', 'Change the default zone';
    assert_script_run("firewall-cmd --set-default-zone=dmz");

    # Change to the default zone
    record_info 'Set Default Zone';
    assert_script_run("firewall-cmd --set-default-zone=public");
}

# Test #7 - Create a rule using --timeout and verifying if the rule vanishes after the specified period
sub test7 {
    record_info 'Test #7', 'Create a rule using timeout';
    script_run("iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules.txt");

    assert_script_run("firewall-cmd --zone=public --add-service=smtp --timeout=30");

    if (is_tumbleweed) {
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW,UNTRACKED -j ACCEPT");
    }
    else {
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW -j ACCEPT");
    }

    assert_script_run("sleep 35");
    assert_script_run("if [ `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules.txt`  ]; then /usr/bin/true; else /usr/bin/false; fi");

}

# Test #8 - Create a custom service
sub test8 {
    record_info 'Test #8', 'Create a custom service';
    assert_script_run("sed -e 's/22/3050/' -e 's/SSH/FBSQL/' /usr/lib/firewalld/services/ssh.xml | awk '{doit=1} doit{sub(/<description>[^<]+<\\/description>/, \"<description>FBSQL is the protocol for the FirebirdSQL Relational Database</description>\"); print} {doit=0}' > /etc/firewalld/services/fbsql.xml");
    assert_script_run("firewall-cmd --reload");
    assert_script_run("firewall-cmd --get-services | grep -i fbsql");
    assert_script_run("rm -rf /etc/firewalld/services/fbsql.xml");
}

sub run {
    select_console("root-console");

    # Check Service State, enable it if necessary, set default zone to public
    pre_test;

    # Test #1 - Stop firewalld then start it
    test1;

    # Test #2 - Temporary rules
    test2;

    # Test #3 - Permanent rules
    test3;

    # Test #4 - Masquerading
    test4;

    # Test #5 - ipv4 adress family with rich rules
    test5;

    # Test #6 - Change the default zone
    test6;

    # Test #7 - Create a rule using --timeout and verifying if the rule vanishes after the specified period
    test7;

    # Test #8 - Create a custom service
    test8;

}

1;
