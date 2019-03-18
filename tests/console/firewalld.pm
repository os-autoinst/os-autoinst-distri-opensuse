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
use transactional_system 'trup_install';

sub run {
    select_console("root-console");

    # Check Service State, enable it if necessary
    record_info 'Check Service State';
    assert_script_run("if [ `firewall-cmd --state > /dev/null 2>&1 ; echo $?` -eq 252 ]; then systemctl start firewalld; fi");

    # Test #1 - Stop firewalld then start it
    record_info 'Test #1', 'Test: Stop firewalld, then start it';
    assert_script_run("systemctl stop firewalld");
    assert_script_run("systemctl start firewalld");

    # Check Service State, enable it if necessary
    record_info 'Check Service State';
    assert_script_run("if [ `firewall-cmd --state > /dev/null 2>&1 ; echo $?` -eq 252 ]; then systemctl start firewalld; fi");


    # Test #2 - Temporary rules
    record_info 'Test #2', 'Test Temporary Rules';
    assert_script_run("firewall-cmd --zone=public --add-port=25/tcp");
    assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW -j ACCEPT");

    assert_script_run("firewall-cmd --zone=public --add-service=ssh");
    assert_script_run("iptables -C IN_public_allow -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT");

    assert_script_run("firewall-cmd --zone=public --add-protocol=icmp");
    assert_script_run("iptables -C IN_public_allow -p icmp -m conntrack --ctstate NEW -j ACCEPT");

    assert_script_run("firewall-cmd --zone=public --add-port=2000-3000/udp");
    assert_script_run("iptables -C IN_public_allow -p udp --dport 2000:3000 -m conntrack --ctstate NEW -j ACCEPT");

    # Flush rules
    record_info 'Flush Rules';
    assert_script_run("firewall-cmd --reload");
    assert_script_run("if [ `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq 0 ]; then /usr/bin/true; else /usr/bin/false; fi");
    

    # Test #3 - Permanent rules
    record_info 'Test #3', 'Test Permanent Rules';
    assert_script_run("firewall-cmd --zone=public --permanent --add-port=25/tcp");
    assert_script_run("firewall-cmd --zone=public --permanent --add-service=ssh");
    assert_script_run("firewall-cmd --zone=public --permanent --add-protocol=icmp");
    assert_script_run("firewall-cmd --zone=public --permanent --add-port=2000-3000/udp");

    assert_script_run("firewall-cmd --reload");

    assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW -j ACCEPT");
    assert_script_run("iptables -C IN_public_allow -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT");
    assert_script_run("iptables -C IN_public_allow -p icmp -m conntrack --ctstate NEW -j ACCEPT");
    assert_script_run("iptables -C IN_public_allow -p udp --dport 2000:3000 -m conntrack --ctstate NEW -j ACCEPT");

    # Flush rules
    record_info 'Flushing rules';
    assert_script_run("firewall-cmd --zone=public --permanent --remove-port=25/tcp");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-service=ssh");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-protocol=icmp");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-port=2000-3000/udp");
    assert_script_run("firewall-cmd --reload");
    assert_script_run("if [ `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq 0 ]; then /usr/bin/true; else /usr/bin/false; fi");
 

    # Test #4 - Masquerading
    record_info 'Test #4', 'Test Rules using Masquerading';
    assert_script_run("firewall-cmd --zone=public --add-masquerade");
    assert_script_run("firewall-cmd --zone=public --add-forward-port=port=2222:proto=tcp:toport=22");
    assert_script_run("iptables -t mangle -C PRE_public_allow -p tcp --dport 2222 -j MARK --set-mark `iptables -t mangle -L PRE_public_allow | grep -i MARK | sed 's/set /\$ /' | cut -f 2 -d \"\$\"`");
    assert_script_run("iptables -t nat -C PRE_public_allow -p tcp -m mark --mark `iptables -t mangle -L PRE_public_allow | grep -i MARK | sed 's/set /\$ /' | cut -f 2 -d \"\$\"` -j DNAT --to :22");

    # Reload default state and flush rules
    record_info 'Flushing Rules';
    assert_script_run("firewall-cmd --reload");
    assert_script_run("if [ `iptables -t mangle -L PRE_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq 0 ]; then /usr/bin/true; else /usr/bin/false; fi");
    assert_script_run("if [ `iptables -t nat -L PRE_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq 0 ]; then /usr/bin/true; else /usr/bin/false; fi");
 

    # Test #5 - ipv4 adress family with rich rules
    record_info 'Test #5", "Test ipv4 family addresses with rich rules';
    assert_script_run("firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=\"ipv4\" source address=192.168.200.0/24 accept'");
    assert_script_run("firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=\"ipv4\" source address=192.168.201.0/24 drop'");
    assert_script_run("firewall-cmd --reload");
    assert_script_run("iptables -C IN_public_allow -s 192.168.200.0/24 -j ACCEPT");
    assert_script_run("iptables -C IN_public_deny -s 192.168.201.0/24 -j DROP");
 

    # Reload default state and flush rules
    record_info 'Flushing rules';
    assert_script_run("firewall-cmd --zone=public --permanent --remove-rich-rule 'rule family=\"ipv4\" source address=192.168.200.0/24 accept'");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-rich-rule 'rule family=\"ipv4\" source address=192.168.201.0/24 drop'");
    assert_script_run("firewall-cmd --reload");
    assert_script_run("if [ `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq 0 ]; then /usr/bin/true; else /usr/bin/false; fi");
    assert_script_run("if [ `iptables -L IN_public_deny --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq 0 ]; then /usr/bin/true; else /usr/bin/false; fi");
 

    # Test #6 - Change the default zone
    record_info 'Test #6', 'Change the default zone';
    assert_script_run("firewall-cmd --set-default-zone=public");
    assert_script_run("if [ a`firewall-cmd --get-default-zone | grep -i 'public'` = \"apublic\" ]; then true; else false; fi");
    assert_script_run("firewall-cmd --set-default-zone=dmz");
    assert_script_run("if [ a`firewall-cmd --get-default-zone | grep -i 'dmz'` = \"admz\" ]; then true; else false; fi");

    # Change to the default zone
    record_info 'Set Default Zone';
    assert_script_run("firewall-cmd --set-default-zone=public");
    assert_script_run("if [ a`firewall-cmd --get-default-zone | grep -i 'public'` = \"apublic\" ]; then true; else false; fi");


    # Test #7 - Create a rule using --timeout and verifying if the rule vanishes after the specified period
    record_info 'Test #7', 'Create a rule using timeout';
    assert_script_run("firewall-cmd --zone=public --add-service=smtp --timeout=30");
    assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW -j ACCEPT");
    assert_script_run("sleep 35");
    assert_script_run("if [ `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq 0 ]; then /usr/bin/true; else /usr/bin/false; fi");


    # Test #8 - Create a custom service
    record_info 'Test #8', 'Create a custom service';
    assert_script_run("sed -e 's/22/3050/' -e 's/SSH/FBSQL/' /usr/lib/firewalld/services/ssh.xml | awk '{doit=1} doit{sub(/<description>[^<]+<\\/description>/, \"<description>FBSQL is the protocol for the FirebirdSQL Relational Database</description>\"); print} {doit=0}' > /etc/firewalld/services/fbsql.xml");
    assert_script_run("firewall-cmd --reload");
    assert_script_run("firewall-cmd --get-services | grep -i fbsql");
    assert_script_run("rm -rf /etc/firewalld/services/fbsql.xml");

}

1;
