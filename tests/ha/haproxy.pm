# SUSE's openQA tests
#
# Copyright (c) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test haproxy resource agent
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils qw(zypper_call systemctl);
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;
    my $haproxy_rsc  = 'haproxy';
    my $haproxy_cfg  = '/etc/haproxy/haproxy.cfg';
    my $apache_file  = '/srv/www/htdocs/index.html';
    my $vip_ip       = '10.0.2.20';
    my $vip_rsc      = 'vip';
    my $node_01      = choose_node(1);
    my $node_02      = choose_node(2);
    my $node_01_ip   = get_ip($node_01);
    my $node_02_ip   = get_ip($node_02);

    # Waiting for the other nodes to be ready
    barrier_wait("HAPROXY_INIT_$cluster_name");

    # Installation of haproxy and apache2 packages
    zypper_call 'in haproxy apache2';
    save_screenshot;

    # Get apache file template from the openQA server
    assert_script_run "curl -f -v " . autoinst_url . "/data/ha/haproxy_apache.template -o $apache_file";

    if (is_node(1)) {
        # Get haproxy configuration file template from the openQA server
        assert_script_run "curl -f -v " . autoinst_url . "/data/ha/haproxy.cfg.template -o $haproxy_cfg";

        # And modify the template according to our needs
        assert_script_run "sed -i 's/%NODE_01%/$node_01/g' $haproxy_cfg";
        assert_script_run "sed -i 's/%NODE_01_IP%/$node_01_ip/g' $haproxy_cfg";
        assert_script_run "sed -i 's/%NODE_02%/$node_02/g' $haproxy_cfg";
        assert_script_run "sed -i 's/%NODE_02_IP%/$node_02_ip/g' $haproxy_cfg";
        assert_script_run "sed -i 's/%VIP_IP%/$vip_ip/g' $haproxy_cfg";

        add_file_in_csync(value => "$haproxy_cfg");

        # Execute csync2 to synchronise the configuration files
        exec_csync;

        # Modify the apache template file according to our needs
        assert_script_run "sed -i 's/%NODE%/$node_01/g' $apache_file";
        assert_script_run "sed -i 's/%IP%/$node_01_ip/g' $apache_file";
    }
    elsif (is_node(2)) {
        # Modify the apache template file according to our needs
        assert_script_run "sed -i 's/%NODE%/$node_02/g' $apache_file";
        assert_script_run "sed -i 's/%IP%/$node_02_ip/g' $apache_file";
    }

    # Apache have to be started on the both nodes for load balancing
    # TODO: Add apache2 in the HA configuration
    systemctl 'enable --now apache2';

    if (is_node(1)) {
        # Create vip resource
        assert_script_run "EDITOR=\"sed -ie '\$ a primitive $vip_rsc IPaddr2 params ip='$vip_ip' nic='eth0' cidr_netmask='24' broadcast='10.0.2.255''\" crm configure edit";

        # Just to be sure that vip resource is started
        sleep 5;
        save_state;

        # Create haproxy resource
        assert_script_run "EDITOR=\"sed -ie '\$ a primitive $haproxy_rsc systemd:haproxy'\" crm configure edit";

        # Vip must be started before haproxy
        assert_script_run "EDITOR=\"sed -ie '\$ a order order_vip_haproxy Mandatory: $vip_rsc $haproxy_rsc'\" crm configure edit";

        # Vip must be started where haproxy is live
        assert_script_run "EDITOR=\"sed -ie '\$ a colocation colocation_vip_haproxy inf: $haproxy_rsc $vip_rsc'\" crm configure edit";

        # Sometimes we need to cleanup the resource
        rsc_cleanup $haproxy_rsc;
    }

    # Do a check of the cluster with a screenshot
    save_state;

    if (is_node(2)) {
        # Test if the HTML content is the one expected on both nodes
        assert_script_run "curl -s $node_02_ip | grep $node_02";
    }
    elsif (is_node(1)) {
        assert_script_run "curl -s $node_01_ip | grep $node_01";
        # Check if haproxy round-robin mode is working
        # The output of both curl commands must be different
        assert_script_run "[[ \$(curl -s $vip_ip:8080) != \$(curl -s $vip_ip:8080) ]]";
    }

    barrier_wait("HAPROXY_DONE_$cluster_name");
}

1;
