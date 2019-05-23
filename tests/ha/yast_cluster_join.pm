# SUSE's openQA tests
#
# Copyright (c) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Join a cluster deployed by YaST
# Maintainer: Julien Adamek <jadamek@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils qw(zypper_call systemctl exec_and_insert_password);
use hacluster;

sub run {
    my $cluster_name = get_cluster_name;
    my $node_to_join = get_node_to_join;
    my $hostname     = get_hostname;

    # Wait until cluster is initialized
    diag 'Wait until cluster is initialized...';
    barrier_wait("CLUSTER_INITIALIZED_$cluster_name");

    # Configure ssh key to enable ssh passwordless
    add_to_known_hosts($node_to_join);
    assert_script_run "ls -altr /root/";
    exec_and_insert_password("scp root\@$node_to_join:/root/.ssh/* /root/.ssh/");
    assert_script_run "ssh root\@$node_to_join 'ssh-keyscan -H $hostname >> /root/.ssh/known_hosts'";

    # Wait until all the nodes have ssh key configured
    barrier_wait("SSH_KEY_CONFIGURED_$cluster_name");

    # Use mutex to be sure that only one node at a time can access the file
    mutex_lock 'csync2';
    # Add this node to master csync2.cfg
    assert_script_run "ssh root\@$node_to_join \"sed -i 's|^}\$|        host $hostname;\\n}|' /etc/csync2/csync2.cfg\"";
    mutex_unlock 'csync2';

    # Copy both csync2.cfg and key_hagroup files from the first node
    assert_script_run("scp root\@$node_to_join:/etc/csync2/csync2.cfg /etc/csync2/csync2.cfg");
    assert_script_run("scp root\@$node_to_join:/etc/csync2/key_hagroup /etc/csync2/key_hagroup");

    # Enable and start csync2
    systemctl 'enable --now csync2.socket';

    # Wait until all the nodes have csync2 configured
    barrier_wait("CSYNC2_CONFIGURED_$cluster_name");

    # Wait csync2 synchronization by the first node
    barrier_wait("CSYNC2_SYNC_$cluster_name");

    # As we have the synced files, we can start pacemaker
    systemctl 'enable --now pacemaker';

    # Signal that the cluster stack is initialized
    barrier_wait("NODE_JOINED_$cluster_name");
}

1;
