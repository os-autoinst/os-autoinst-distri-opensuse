# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Setup network and prepare nodes for SES5 deployment
#          http://docserv.suse.de/documents/Storage_5/ses-deployment/single-html/#ceph.install.stack
# Maintainer: Jozef Pupava <jpupava@suse.cz>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use mm_network;
use lockapi;
use utils qw(systemctl zypper_call);
use version_utils 'is_sle';

sub restart_and_sync_chrony {
    systemctl "restart chronyd";
    systemctl "status chronyd";
    assert_script_run 'chronyc waitsync 40 0.01 && chronyc sources', 400;
}

sub run {
    select_console 'root-console';
    if (check_var('HOSTNAME', 'master')) {
        # create mutex lock and barriers
        mutex_create('master_ready');
        my $all_ses_nodes = get_var('NODE_COUNT') + 1;
        barrier_create('network_configured', $all_ses_nodes);
        barrier_create('master_chrony_ready', $all_ses_nodes);
        barrier_create('deployment_done', $all_ses_nodes);
        barrier_create('all_tests_done', $all_ses_nodes);
    }
    else {
        mutex_lock('master_ready');
        mutex_unlock('master_ready');
    }
    # only one job (master) should check for dead jobs to avoid failures
    my $only_master_check = check_var('HOSTNAME', 'master') ? 1 : 0;
    barrier_wait {name => 'network_configured', check_dead_job => $only_master_check};
    # disable ipv6
    assert_script_run 'echo \'net.ipv6.conf.all.disable_ipv6 = 1\' >> /etc/sysctl.conf';
    # deepsea testsuite does not need to use supportserver
    if (get_var('DEEPSEA_TESTSUITE')) {
        # set node hostname
        my $node_hostname = get_var('HOSTNAME');
        assert_script_run "hostnamectl set-hostname $node_hostname";
        # configure network
        configure_default_gateway;
        my $node_ip = get_var('NODE_IP');
        configure_static_ip(ip => "$node_ip/24");
        configure_static_dns(get_host_resolv_conf());
        restart_networking();
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
    }
    else {
        # restart network, get IP from supportserver
        systemctl 'restart network';
    }
    assert_script_run 'ip a';
    assert_script_run 'for i in {1..7}; do echo "try $i" && fping -c2 -q updates.suse.com && sleep 2 && break; done';
    # firewall and apparmor should not run
    my $firewall = is_sle('15+') ? 'firewalld' : 'SuSEfirewall2';
    systemctl "disable $firewall";
    systemctl "stop $firewall";
    systemctl 'disable apparmor';
    systemctl 'stop apparmor';
    # configure and start chrony, time synchroniation server for nodes is master
    my $ntp_server = check_var('HOSTNAME', 'master') ? 'ntp.suse.de' : 'master.openqa.test';
    assert_script_run "sed -i '/pool/d' /etc/chrony.conf";
    if (check_var('HOSTNAME', 'master')) {
        # set ntp server and add allow for nodes to sync with master
        assert_script_run "echo -e \"server $ntp_server iburst\\nallow\" >> /etc/chrony.conf";
        restart_and_sync_chrony;
        barrier_wait {name => 'master_chrony_ready', check_dead_job => $only_master_check};
        assert_script_run 'echo "master_minion: master.openqa.test" >/srv/pillar/ceph/master_minion.sls';
    }
    else {
        assert_script_run "echo 'server $ntp_server iburst' >> /etc/chrony.conf";
        barrier_wait {name => 'master_chrony_ready', check_dead_job => $only_master_check};
        restart_and_sync_chrony;
    }
    assert_script_run "grep -v ^# /etc/chrony.conf";
    # check repositories only when it's QAM update
    if (get_var('SES_TEST_ISSUES')) {
        # repositories must contain SLE, SES and QAM update repo
        my $incident_number = get_var('SES_TEST_ISSUES');
        my $version = get_var('VERSION');
        validate_script_output('zypper lr -u', sub { m/$version/ && m/SUSE-Enterprise-Storage/ && m/Maintenance:\/$incident_number/ });
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

