# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup network and prepare nodes for SES5 deployment
#          http://docserv.suse.de/documents/Storage_5/ses-deployment/single-html/#ceph.install.stack
# Maintainer: Jozef Pupava <jpupava@suse.cz>

use base 'opensusebasetest';
use strict;
use testapi;
use mm_network;
use lockapi;
use utils 'systemctl';

sub run {
    select_console 'root-console';
    # configure and start ntp, ntp server for nodes is master
    if (check_var('HOSTNAME', 'master')) {
        my $all_ses_nodes = get_var('NODE_COUNT') + 1;
        barrier_create('network_configured', $all_ses_nodes);
        barrier_create('deployment_done',    $all_ses_nodes);
        barrier_create('all_tests_done',     $all_ses_nodes);
        assert_script_run 'echo \'server ntp1.suse.de burst iburst\' >> /etc/ntp.conf';
    }
    else {
        assert_script_run 'echo \'server master.openqa.test burst iburst\' >> /etc/ntp.conf';
    }
    # print the ntp config
    assert_script_run 'grep -v ^# /etc/ntp.conf';
    systemctl 'restart ntpd';
    # disable ipv6
    assert_script_run 'echo \'net.ipv6.conf.all.disable_ipv6 = 1\' >> /etc/sysctl.conf';
    systemctl 'restart network' unless get_var('DEEPSEA_TESTSUITE');
    # firewall and apparmor should not run
    systemctl 'stop SuSEfirewall2';
    systemctl 'disable SuSEfirewall2';
    systemctl 'stop apparmor';
    systemctl 'disable apparmor';
    # only one job (master) should check for dead jobs to avoid failures
    my $only_master_check = check_var('HOSTNAME', 'master') ? 1 : 0;
    if (get_var('DEEPSEA_TESTSUITE')) {
        # set node hostname
        my $node_hostname = get_var('HOSTNAME');
        assert_script_run "hostnamectl set-hostname $node_hostname";
        # configure network
        configure_default_gateway;
        my $node_ip = get_var('NODE_IP');
        configure_static_ip("$node_ip/24");
        configure_static_dns(get_host_resolv_conf());
        # add node entries to /etc/hosts
        my $hosts = <<'EOF';
echo -e '10.0.2.100\tmaster.openqa.test master' >> /etc/hosts
echo -e '10.0.2.101\tnode1.openqa.test node1' >> /etc/hosts
echo -e '10.0.2.102\tnode2.openqa.test node2' >> /etc/hosts
echo -e '10.0.2.103\tnode3.openqa.test node3' >> /etc/hosts
echo -e '10.0.2.104\tnode4.openqa.test node4' >> /etc/hosts
EOF
        script_run($_) foreach (split /\n/, $hosts);
        assert_script_run 'cat /etc/hosts';
        barrier_wait {name => 'network_configured', check_dead_job => $only_master_check};
        # nodes will ping each other to test connection
        assert_script_run 'fping -c2 -q $(grep \'openqa.test\' /etc/hosts|awk \'{print$2}\'|tr "\n" " ")';
    }
    else {
        barrier_wait {name => 'network_configured', check_dead_job => $only_master_check};
        assert_script_run 'ip a';
        assert_script_run 'for i in {1..7}; do echo "try $i" && fping -c2 -q updates.suse.com 10.0.2.2 && sleep 2 && break; done';
    }
    # check repositories, should contain SLE, SES and QAM update repo
    my $incident_number = get_var('SES_TEST_ISSUES');
    my $version         = get_var('VERSION');
    validate_script_output('zypper lr -u', sub { m/$version/ && m/SUSE-Enterprise-Storage/ && m/Maintenance:\/$incident_number/ });
}

sub test_flags {
    return {fatal => 1};
}

1;

