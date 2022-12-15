# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: firewalld
# Summary: Test FirewallD basic usage, including nftables/iptables
# Maintainer: Alexandre Makoto Tanno <atanno@suse.com>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils qw(systemctl zypper_call);
use version_utils qw(is_sle is_leap);

sub uses_iptables {
    return is_sle('<15-SP3') || is_leap('<15.3');
}

# Check Service State, enable it if necessary, set default zone to public
sub pre_test {
    zypper_call('in firewalld');
    zypper_call('info firewalld');
    record_info 'Check Service State';
    script_run('echo "FIREWALLD_ARGS=--debug" >> /etc/sysconfig/firewalld');
    systemctl('enable --now firewalld');
    assert_script_run("firewall-cmd --set-default-zone=public");
}

sub check_rules {
    if (uses_iptables) {
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW -j ACCEPT");
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 110 -m conntrack --ctstate NEW -j ACCEPT");
        assert_script_run("iptables -C IN_public_allow -p icmp -m conntrack --ctstate NEW -j ACCEPT");
        assert_script_run("iptables -C IN_public_allow -p udp --dport 2000:3000 -m conntrack --ctstate NEW -j ACCEPT");
    }
    else {
        assert_script_run("nft list chain inet firewalld filter_IN_public_allow | grep 25");
        assert_script_run("nft list chain inet firewalld filter_IN_public_allow | grep 110");
        if (is_leap("<16.0") || is_sle("<16")) {
            assert_script_run("nft list chain inet firewalld filter_FWDI_public | grep icmp");
        } else {
            assert_script_run("nft list chain inet firewalld filter_FWD_public | grep icmp");
        }
        assert_script_run("nft list chain inet firewalld filter_IN_public_allow | grep 2000-3000");
    }
}

# Test #1 - Stop firewalld then start it
sub start_stop_firewalld {
    record_info 'Service start', 'Test: Stop firewalld, then start it';
    systemctl('stop firewalld');
    systemctl('start firewalld');
    # wait until iptables -L can print rules, max 10 seconds
    if (uses_iptables) {
        assert_script_run('timeout 10 bash -c "until iptables -L IN_public_allow; do sleep 1;done"');
    }
    else {
        assert_script_run('timeout 10 bash -c "until nft list chain inet firewalld filter_IN_public_allow; do sleep 1;done"');
    }
}

# Store the count of rules in IN and FWD(I) chains in /tmp/nr_* files
sub collect_in_fwd_rule_count {
    if (uses_iptables) {
        assert_script_run("iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules.txt");
    }
    else {
        assert_script_run("nft list chain inet firewalld filter_IN_public_allow | wc -l > /tmp/nr_in_public.txt");
        if (is_leap("<16.0") || is_sle("<16")) {
            assert_script_run("nft list chain inet firewalld filter_FWDI_public | wc -l > /tmp/nr_fwdi_public.txt");
        } else {
            assert_script_run("nft list chain inet firewalld filter_FWD_public | wc -l > /tmp/nr_fwd_public.txt");
        }
    }
}

# Compare the count of rules in in and FWD(I) chains against the saved counts in /tmp/nr_* files
sub verify_in_fwd_rule_count {
    if (uses_iptables) {
        assert_script_run("test `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules.txt`");
    }
    else {
        assert_script_run("test `nft list chain inet firewalld filter_IN_public_allow | wc -l` -eq `cat /tmp/nr_in_public.txt`");
        if (is_leap("<16.0") || is_sle("<16")) {
            assert_script_run("test `nft list chain inet firewalld filter_FWDI_public | wc -l` -eq `cat /tmp/nr_fwdi_public.txt`");
        } else {
            assert_script_run("test `nft list chain inet firewalld filter_FWD_public | wc -l` -eq `cat /tmp/nr_fwd_public.txt`");
        }
    }
}

# Test #2 - Temporary Rules
sub test_temporary_rules {
    record_info 'Temporary rules', 'Test Temporary Rules';
    collect_in_fwd_rule_count;

    assert_script_run("firewall-cmd --zone=public --add-port=25/tcp");
    assert_script_run("firewall-cmd --zone=public --add-service=pop3");
    assert_script_run("firewall-cmd --zone=public --add-protocol=icmp");
    assert_script_run("firewall-cmd --zone=public --add-port=2000-3000/udp");

    check_rules;

    # Reload default configuration
    record_info 'Reload default configuration';
    assert_script_run("firewall-cmd --reload");
    verify_in_fwd_rule_count;
}

# Test #3 - Test Permanent Rules
sub test_permanent_rules {
    # Test Permanent Rules
    record_info 'Permanent Rules', 'Test Permanent Rules';
    collect_in_fwd_rule_count;

    assert_script_run("firewall-cmd --zone=public --permanent --add-port=25/tcp");
    assert_script_run("firewall-cmd --zone=public --permanent --add-service=pop3");
    assert_script_run("firewall-cmd --zone=public --permanent --add-protocol=icmp");
    assert_script_run("firewall-cmd --zone=public --permanent --add-port=2000-3000/udp");

    assert_script_run("firewall-cmd --reload");

    check_rules;

    # Remove rules used in the test and reload default configuration
    record_info 'Remove rules and reload default configuration';
    assert_script_run("firewall-cmd --zone=public --permanent --remove-port=25/tcp");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-service=pop3");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-protocol=icmp");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-port=2000-3000/udp");
    assert_script_run("firewall-cmd --reload");
    verify_in_fwd_rule_count;
}

# Test #4 - Test Rules using Masquerading
sub test_masquerading {
    record_info 'Masquerading tests', 'Test Rules using Masquerading';
    if (uses_iptables) {
        assert_script_run("iptables -t nat -L PRE_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules_nat_pre.txt");
        assert_script_run("iptables -t nat -L POST_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules_nat_post.txt");
    } elsif (is_leap("<16.0") || is_sle("<16")) {
        assert_script_run("nft list chain ip firewalld nat_PRE_public_allow | wc -l > /tmp/nr_rules_nat_pre.txt");
        assert_script_run("nft list chain ip firewalld nat_POST_public_allow | wc -l > /tmp/nr_rules_nat_post.txt");
    } else {
        assert_script_run("nft list chain inet firewalld nat_PRE_public_allow | wc -l > /tmp/nr_rules_nat_pre.txt");
        assert_script_run("nft list chain inet firewalld nat_POST_public_allow | wc -l > /tmp/nr_rules_nat_post.txt");
    }

    assert_script_run("firewall-cmd --zone=public --add-masquerade");
    assert_script_run("firewall-cmd --zone=public --add-forward-port=port=2222:proto=tcp:toport=22");

    if (uses_iptables) {
        assert_script_run("iptables -t nat -L PRE_public_allow | grep 'to::22'");
        assert_script_run("iptables -t nat -L POST_public_allow | grep MASQUERADE");
    } elsif (is_leap("<16.0") || is_sle("<16")) {
        assert_script_run("nft list chain ip firewalld nat_PRE_public_allow | grep 'redirect to :22'");
        assert_script_run("nft list chain ip firewalld nat_POST_public_allow | grep masquerade");
    } else {
        assert_script_run("nft list chain inet firewalld nat_PRE_public_allow | grep 'redirect to :22'");
        assert_script_run("nft list chain inet firewalld nat_POST_public_allow | grep masquerade");
    }

    # Reload default configuration
    record_info 'Reload default configuration';
    assert_script_run("firewall-cmd --reload");
    if (uses_iptables) {
        assert_script_run("test `iptables -t nat -L PRE_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules_nat_pre.txt`");
        assert_script_run("test `iptables -t nat -L POST_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules_nat_post.txt`");
    } elsif (is_leap("<16.0") || is_sle("<16")) {
        assert_script_run("test `nft list chain ip firewalld nat_PRE_public_allow | wc -l` -eq `cat /tmp/nr_rules_nat_pre.txt`");
        assert_script_run("test `nft list chain ip firewalld nat_POST_public_allow | wc -l` -eq `cat /tmp/nr_rules_nat_post.txt`");
    } else {
        assert_script_run("test `nft list chain inet firewalld nat_PRE_public_allow | wc -l` -eq `cat /tmp/nr_rules_nat_pre.txt`");
        assert_script_run("test `nft list chain inet firewalld nat_POST_public_allow | wc -l` -eq `cat /tmp/nr_rules_nat_post.txt`");
    }
}

# Test #5 - Test ipv4 family addresses with rich rules
sub test_rich_rules {
    record_info 'Rich rules tests", "Test ipv4 family addresses with rich rules';
    if (uses_iptables) {
        assert_script_run("iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules_allow.txt");
        assert_script_run("iptables -L IN_public_deny --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules_deny.txt");
    }
    else {
        assert_script_run("nft list chain inet firewalld filter_IN_public_allow | wc -l > /tmp/nr_rules_allow.txt");
        assert_script_run("nft list chain inet firewalld filter_IN_public_deny | wc -l > /tmp/nr_rules_deny.txt");
    }

    assert_script_run("firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=\"ipv4\" source address=192.168.200.0/24 accept'");
    assert_script_run("firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=\"ipv4\" source address=192.168.201.0/24 drop'");
    assert_script_run("firewall-cmd --reload");

    if (uses_iptables) {
        assert_script_run("iptables -C IN_public_allow -s 192.168.200.0/24 -j ACCEPT");
        assert_script_run("iptables -C IN_public_deny -s 192.168.201.0/24 -j DROP");
    }
    else {
        assert_script_run("nft list chain inet firewalld filter_IN_public_allow | grep 192.168.200.0/24");
        assert_script_run("nft list chain inet firewalld filter_IN_public_deny | grep 192.168.201.0/24");
    }

    # Reload default configuration and flush rules
    record_info 'Remove rules used during the test and reload default configuration';
    assert_script_run("firewall-cmd --zone=public --permanent --remove-rich-rule 'rule family=\"ipv4\" source address=192.168.200.0/24 accept'");
    assert_script_run("firewall-cmd --zone=public --permanent --remove-rich-rule 'rule family=\"ipv4\" source address=192.168.201.0/24 drop'");
    assert_script_run("firewall-cmd --reload");

    if (uses_iptables) {
        assert_script_run("test `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules_allow.txt`");
        assert_script_run("test `iptables -L IN_public_deny --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules_deny.txt`");
    }
    else {
        assert_script_run("test `nft list chain inet firewalld filter_IN_public_allow | wc -l` -eq `cat /tmp/nr_rules_allow.txt`");
        assert_script_run("test `nft list chain inet firewalld filter_IN_public_deny | wc -l` -eq `cat /tmp/nr_rules_deny.txt`");
    }
}

# Test #6 - Change the default zone
sub test_default_zone {
    record_info 'Default zone change test', 'Change the default zone';
    assert_script_run("firewall-cmd --set-default-zone=dmz");

    # Change to the default zone
    record_info 'Set Default Zone';
    assert_script_run("firewall-cmd --set-default-zone=public");
}

# Test #7 - Create a rule using --timeout and verifying if the rule vanishes after the specified period
sub test_timeout_rules {
    record_info 'Timeout rules tests', 'Create a rule using timeout';
    if (uses_iptables) {
        assert_script_run("iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l > /tmp/nr_rules.txt");
    }
    else {
        assert_script_run("nft list chain inet firewalld filter_IN_public_allow | wc -l > /tmp/nr_rules.txt");
    }

    assert_script_run("firewall-cmd --zone=public --add-service=smtp --timeout=30");

    if (uses_iptables) {
        assert_script_run("iptables -C IN_public_allow -p tcp --dport 25 -m conntrack --ctstate NEW -j ACCEPT");
    }
    else {
        assert_script_run("nft list chain inet firewalld filter_IN_public_allow | grep 25");
    }

    assert_script_run("sleep 35");
    if (uses_iptables) {
        assert_script_run("test `iptables -L IN_public_allow --line-numbers | sed '/^num\\|^\$\\|^Chain/d' | wc -l` -eq `cat /tmp/nr_rules.txt`");
    }
    else {
        assert_script_run("test `nft list chain inet firewalld filter_IN_public_allow | wc -l` -eq `cat /tmp/nr_rules.txt`");
    }

}

# Test #8 - Create a custom service
sub test_custom_services {
    record_info 'Custom services tests', 'Create a custom service';
    assert_script_run("sed -e 's/22/3050/' -e 's/SSH/FBSQL/' /usr/lib/firewalld/services/ssh.xml | awk '{doit=1} doit{sub(/<description>[^<]+<\\/description>/, \"<description>FBSQL is the protocol for the FirebirdSQL Relational Database</description>\"); print} {doit=0}' > /etc/firewalld/services/fbsql.xml");
    assert_script_run("firewall-cmd --reload");
    assert_script_run("firewall-cmd --get-services | grep -i fbsql");
    assert_script_run("rm -rf /etc/firewalld/services/fbsql.xml");
}

sub test_default_backend {
    validate_script_output('iptables', sub {
        if (uses_iptables){
	   qr/legacy/
	} else {
	  record_soft_failure('https://bugzilla.suse.com/show_bug.cgi?id=1206383') if qr/legacy/;
	  qr/nf_tables/
	}
    });
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Check Service State, enable it if necessary, set default zone to public
    pre_test;

    # Test #1 - Stop firewalld then start it
    start_stop_firewalld;

    # Test #2 - Temporary rules
    test_temporary_rules;

    # Test #3 - Permanent rules
    test_permanent_rules;

    # Test #4 - Masquerading
    test_masquerading;

    # Test #5 - ipv4 adress family with rich rules
    test_rich_rules;

    # Test #6 - Change the default zone
    test_default_zone;

    # Test #7 - Create a rule using --timeout and verifying if the rule vanishes after the specified period
    test_timeout_rules;

    # Test #8 - Create a custom service
    test_custom_services;

    # Test #9 - Ensure we have the correct backend
    test_default_backend;
}

sub post_fail_hook {
    my ($self) = shift;
    upload_logs("/var/log/firewalld");
    $self->SUPER::post_fail_hook;
}

1;
