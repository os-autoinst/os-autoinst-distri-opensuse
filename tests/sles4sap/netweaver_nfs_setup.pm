# SUSE's SLES4SAP openQA tests

#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Set up NFS server and clients for NetWeaver tests
# This is not done with the generic supportserver module, because
# the sles4sap class methods are required.
#
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(systemctl);
use hacluster;
use lockapi;

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my $cluster_infos = get_required_var 'CLUSTER_INFOS';
    my ($cluster_name, $num_nodes) = split /:/, $_;
    my $nfs_root = get_required_var 'NFS_MOUNT';
    my $nw_install_data = $self->netweaver_installation_data();
    my $create_directories = join ',', 'sapmnt', 'SYS';
    my $sap_sid = $nw_install_data->{instance_sid};
    my $sap_dir = $nw_install_data->{sap_directory};

    if (check_var('SUPPORT_SERVER', '1')) {
        # The supportserver will host the NFS server and then wait for all nodes
        # to mount the client filesystems.

        # We create the barrier here to avoid race conditions. The supportserver
        # will also wait at the barrier later.
        barrier_create 'NFS_MOUNTS_READY', $num_nodes + 1;

        # NFS Server config
        systemctl 'stop nfs-server';
        systemctl 'start rpcbind';
        mutex_lock 'support_server_ready';
        my $nfs_permissions = get_required_var 'NFS_PERMISSIONS';
        record_info 'NFS prep', 'Preparing SAP related exports';
        assert_script_run "mkdir -p $nfs_root/$sap_sid/{$create_directories}";
        assert_script_run "echo $nfs_root *\($nfs_permissions\) >> /etc/exports";
        assert_script_run 'exportfs -r';
        systemctl 'restart nfs-server';
        systemctl 'restart rpcbind';
        systemctl 'is-active nfs-server -a rpcbind';

        # NFS Server is ready to accept clients. Tell the nodes to continue.
        mutex_create 'NFS_SERVER_READY';

        # Wait for the nodes to mount the NFS locally.
        barrier_wait 'NFS_MOUNTS_READY';
    } else {
        # On the node side, wait for the supportserver to set the NFS server up,
        # add then mount the NFS on the client nodes.
        mutex_wait 'NFS server ready';
        record_info 'NFS mounts', 'Preparing shared NFS filesystems';
        assert_script_run "mkdir -p /sapmnt $sap_dir/{$create_directories}";
        assert_script_run "echo 'ns:$nfs_root/$sap_sid/sapmnt /sapmnt nfs defaults 0 0' >> /etc/fstab";
        assert_script_run "echo 'ns:$nfs_root/$sap_sid/SYS $sap_dir/SYS nfs defaults 0 0' >> /etc/fstab";
        assert_script_run 'mount -a';
        assert_script_run 'chmod -Rv 777 /sapmnt/"';
        assert_script_run "chmod -Rv 777 $sap_dir/";
        # Setup done. Tell supportserver and the other node to continue.
        barrier_wait 'NFS_MOUNTS_READY';
    }
}
1;
