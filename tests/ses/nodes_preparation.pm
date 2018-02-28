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
    if (check_var('NODE_HOSTNAME', 'master')) {
        my $num_nodes = get_var('NODE_COUNT');
        barrier_create('network_configured', $num_nodes + 1);
        barrier_create('all_tests_done',     $num_nodes + 1);
        assert_script_run 'echo \'server ntp1.suse.de burst iburst\' >> /etc/ntp.conf';
    }
    else {
        assert_script_run 'echo \'server master.openqa.de burst iburst\' >> /etc/ntp.conf';
    }
    systemctl 'restart ntpd';
    # disable ipv6
    assert_script_run 'echo \'net.ipv6.conf.all.disable_ipv6 = 1\' >> /etc/sysctl.conf';
    # avoid zypper timeout/abort issues
    assert_script_run 'sed -i \'s/download.max_silent_tries = 5/download.max_silent_tries = 0/\' /etc/zypp/zypp.conf';
    assert_script_run 'grep download.max_silent_tries /etc/zypp/zypp.conf';
    # firewall and apparmor should not run
    systemctl 'stop SuSEfirewall2';
    systemctl 'disable SuSEfirewall2';
    systemctl 'stop apparmor';
    systemctl 'disable apparmor';
    # set node hostname
    my $node_hostname = get_var('NODE_HOSTNAME');
    assert_script_run "hostnamectl set-hostname $node_hostname";
    # configure network
    configure_default_gateway;
    my $node_ip = get_var('NODE_IP');
    configure_static_ip("$node_ip/24");
    configure_static_dns(get_host_resolv_conf());
    # add node entries to /etc/hosts
    my $hosts = <<'EOF';
echo -e '10.0.2.100\tmaster.openqa.de master' >> /etc/hosts
echo -e '10.0.2.101\tnode1.openqa.de node1' >> /etc/hosts
echo -e '10.0.2.102\tnode2.openqa.de node2' >> /etc/hosts
echo -e '10.0.2.103\tnode3.openqa.de node3' >> /etc/hosts
echo -e '10.0.2.104\tnode4.openqa.de node4' >> /etc/hosts
EOF
    script_run($_) foreach (split /\n/, $hosts);
    if (get_var('EDGECAST')) {
        record_info 'Netfix', 'Go through Europe Microfocus info-bloxx';
        my $edgecast_europe = get_var('EDGECAST');
        assert_script_run "echo $edgecast_europe updates.suse.com >> /etc/hosts";
    }
    assert_script_run 'cat /etc/hosts';
    barrier_wait {name => 'network_configured', check_dead_job => 1};
    # nodes will ping each other to test connection
    assert_script_run 'fping -c2 -q $(grep \'openqa.de\' /etc/hosts|awk \'{print$2}\'|tr "\n" " ")';
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
