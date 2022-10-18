# SUSE's SLES4SAP openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure NetWeaver network
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.de>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use hacluster;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    my $cluster_name = get_cluster_name;
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my ($ip, $netmask) = split '/', get_required_var('INSTANCE_IP_CIDR');
    my $sid = get_required_var('INSTANCE_SID');
    my $alias = lc("sap$sid" . substr($instance_type, 0, 2));

    # Export needed variables
    set_var('INSTANCE_ALIAS', "$alias");

    select_serial_terminal;

    # Get the network interface and add IP alias
    my $eth = script_output "ip -o route | sed -rn '/^default/s/.+dev ([a-z]+[0-9]).+/\\1/p'";
    assert_script_run "ip a a dev $eth $ip/$netmask";

    # Add IP addresses in /etc/hosts
    assert_script_run "echo '$ip $alias' >> /etc/hosts";

    # Synchronize nodes
    barrier_wait "NW_CLUSTER_HOSTS_$cluster_name";

    # At this stage we have passwordless ssh access on all nodes
    if (is_node(1)) {
        # We have to do this for all nodes
        foreach my $num_node (2 .. get_node_number) {
            my $node = choose_node($num_node);
            assert_script_run "scp -o StrictHostKeyChecking=no root\@$node:/etc/hosts /tmp/hosts.$num_node";
        }
        assert_script_run 'grep -Ehv \'^#|^[[:blank:]]*$\' /etc/hosts /tmp/hosts.* | sort -r -u > /tmp/hosts.nw';
        assert_script_run 'mv /tmp/hosts.nw /etc/hosts';

        # Synchronize the hosts file
        add_file_in_csync(value => '/etc/hosts');
    }
}

1;
