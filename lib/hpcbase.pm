# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Base module for HPC tests
# Maintainer: Sebastian Chlad <schlad@suse.de>

package hpcbase;
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

=head2 enable_and_start

Enables and starts given systemd service

=cut
sub enable_and_start {
    my ($self, $arg) = @_;
    systemctl("enable $arg");
    systemctl("start $arg");
}

sub upload_service_log {
    my ($self, $service_name) = @_;
    script_run("journalctl -u $service_name > /tmp/$service_name");
    script_run("cat /tmp/$service_name");
    upload_logs("/tmp/$service_name", failok => 1);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->select_serial_terminal;
    script_run("journalctl -o short-precise > /tmp/journal.log");
    script_run('cat /tmp/journal.log');
    upload_logs('/tmp/journal.log', failok => 1);
    upload_service_log('wickedd-dhcp4.service');
}

sub switch_user {
    my ($self, $username) = @_;
    type_string("su - $username\n");
    assert_screen 'user-nobody';
}

=head2 master_node_names

Prepare master node names, so those names could be reused, for instance
in config preparation, munge key distribution, etc.
The naming follows general pattern of master-slave

=cut
sub master_node_names {
    my ($self) = @_;
    my $master_nodes = get_required_var("MASTER_NODES");
    my @master_node_names;

    for (my $node = 0; $node < $master_nodes; $node++) {
        my $name = sprintf("master-node%02d", $node);
        push @master_node_names, $name;
    }

    return @master_node_names;
}

=head2 slave_node_names

Prepare compute node names, so those names could be reused, for
instance in config preparation, munge key distribution, etc.
The naming follows general pattern of master-slave

=cut
sub slave_node_names {
    my ($self)       = @_;
    my $master_nodes = get_required_var("MASTER_NODES");
    my $nodes        = get_required_var("CLUSTER_NODES");
    my @slave_node_names;

    my $slave_nodes = $nodes - $master_nodes;
    for (my $node = 0; $node < $slave_nodes; $node++) {
        my $name = sprintf("slave-node%02d", $node);
        push @slave_node_names, $name;
    }

    return @slave_node_names;
}

=head2 cluster_names

Prepare all node names, so those names could be reused

=cut
sub cluster_names {
    my ($self) = @_;
    my @cluster_names;

    my @master_nodes = master_node_names();
    my @slave_nodes  = slave_node_names();

    push(@master_nodes, @slave_nodes);
    @cluster_names = @master_nodes;

    return @cluster_names;
}

sub distribute_munge_key {
    my ($self) = @_;
    my @cluster_nodes = cluster_names();
    foreach (@cluster_nodes) {
        script_run("scp -o StrictHostKeyChecking=no /etc/munge/munge.key root\@$_:/etc/munge/munge.key");
    }
}

sub distribute_slurm_conf {
    my ($self) = @_;
    my @cluster_nodes = cluster_names();
    foreach (@cluster_nodes) {
        script_run("scp -o StrictHostKeyChecking=no /etc/slurm/slurm.conf root\@$_:/etc/slurm/slurm.conf");
    }
}

sub generate_and_distribute_ssh {
    my ($self) = @_;
    my @cluster_nodes = cluster_names();
    assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -f ~/.ssh/id_rsa');
    foreach (@cluster_nodes) {
        exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no root\@$_");
    }
}

sub check_nodes_availability {
    my ($self) = @_;
    my @cluster_nodes = cluster_names();
    foreach (@cluster_nodes) {
        assert_script_run("ping -c 3 $_");
    }
}

sub mount_nfs {
    my ($self) = @_;
    zypper_call('in nfs-client rpcbind');
    ## TODO: get rid of hardcoded name for the NFS-dir
    systemctl("start nfs");
    systemctl("start rpcbind");
    record_info('show mounts aviable on the supportserver', script_output('showmount -e 10.0.2.1'));
    assert_script_run('mkdir -p /shared/slurm');
    assert_script_run('chown -Rcv slurm:slurm /shared/slurm');
    assert_script_run('mount -t nfs -o nfsvers=3 10.0.2.1:/nfs/shared /shared/slurm');
}

=head2 prepare_user_and_group

Creating slurm user and group with some pre-defined ID

=cut
sub prepare_user_and_group {
    my ($self) = @_;
    assert_script_run('groupadd slurm -g 7777');
    assert_script_run('useradd -u 7777 -g 7777 slurm');
}

1;
