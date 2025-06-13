# SUSE's SLES4SAP openQA tests

#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Set up NFS server and clients for NetWeaver tests
# This is not done with the generic supportserver module, because the sles4sap
# class methods are required. It is important that this module is behind a
# barrier like BARRIER_HA_$cluster.
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
    select_serial_terminal();
    my $nfs_root = get_required_var('NFS_MOUNT');
    my $nw_install_data = $self->netweaver_installation_data();
    my $create_directories = join(',', 'sapmnt', 'SYS');
    my $sap_sid = $nw_install_data->{instance_sid};
    my $sap_dir = $nw_install_data->{sap_directory};

    my $mutex = 'nfs_server_ready';
    if (check_var('SUPPORT_SERVER', '1')) {
        # The supportserver will host the NFS server and the nodes will use it as clients
        my ($cluster_name, $num_nodes) = (get_cluster_info()->{cluster_name}, get_cluster_info()->{num_nodes});

        # NFS Server config
        systemctl('stop nfs-server');
        systemctl('start rpcbind');
        my $nfs_permissions = get_required_var('NFS_PERMISSIONS');
        record_info('NFS prep', 'Preparing SAP related exports');
        assert_script_run("mkdir -p $nfs_root/$sap_sid/{$create_directories}");
        assert_script_run("echo $nfs_root *\($nfs_permissions\) >> /etc/exports");
        assert_script_run('exportfs -r');
        systemctl('restart nfs-server');
        systemctl('restart rpcbind');
        systemctl('is-active nfs-server -a rpcbind');
        mutex_create($mutex);

    } else {
        # On the node side, wait for the supportserver to set the NFS server up,
        # add then mount the NFS on the client nodes.
        mutex_wait($mutex);
        record_info('NFS mounts', 'Preparing shared NFS filesystems');
        assert_script_run("mkdir -p /sapmnt $sap_dir/{$create_directories}");
        assert_script_run("echo 'ns:$nfs_root/$sap_sid/sapmnt /sapmnt nfs defaults 0 0' >> /etc/fstab");
        assert_script_run("echo 'ns:$nfs_root/$sap_sid/SYS $sap_dir/SYS nfs defaults 0 0' >> /etc/fstab");
        assert_script_run('mount -a');
        assert_script_run('chmod -Rv 777 /sapmnt/');
        assert_script_run("chmod -Rv 777 $sap_dir/");
        # Setup done. Tell supportserver and the other node to continue.
        # Note: Nodes do not generally get the CLUSTER_INFOS var so we use a different function to get the hostname.
        barrier_wait('NFS_MOUNTS_READY_' . get_cluster_name());
    }
}
1;
