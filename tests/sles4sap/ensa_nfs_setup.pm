# SUSE's SLES4SAP openQA tests

#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure NetWeaver filesystems for ENSA2 based installation
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
    my $cluster_infos = get_required_var('CLUSTER_INFOS');

    my $nfs_root = get_required_var('NFS_MOUNT');
    my $nw_install_data = $self->netweaver_installation_data();
    my $create_directories = join(',', 'sapmnt', 'SYS');
    my $sap_sid = $nw_install_data->{instance_sid};
    my $sap_dir = $nw_install_data->{sap_directory};

    select_serial_terminal;

    # Setup NFS directory structure on supportserver side
    if (check_var('SUPPORT_SERVER', '1')) {
        # On the supportserver side, change NFS Server configuration
        # to have the netweaver mounts
        systemctl('stop nfs-server');
        systemctl('start rpcbind');
        mutex_lock 'support_server_ready';
        my $nfs_permissions = get_required_var("NFS_PERMISSIONS");
        record_info('NFS prep', 'Preparing SAP related exports');

        assert_script_run("mkdir -p $nfs_root/$sap_sid/{$create_directories}");
        assert_script_run("echo $nfs_root *\($nfs_permissions\) >> /etc/exports");
        assert_script_run("exportfs -r");
        systemctl("restart nfs-server");
        systemctl("restart rpcbind");
        systemctl("is-active nfs-server -a rpcbind");
        mutex_unlock 'support_server_ready';
        return;
    }else{
        record_info('NFS mounts', 'Preparing shared NFS filesystems');
        assert_script_run("mkdir -p /sapmnt $sap_dir/{$create_directories}");
        assert_script_run("echo 'ns:$nfs_root/$sap_sid/sapmnt /sapmnt nfs defaults 0 0' >> /etc/fstab");
        assert_script_run("echo 'ns:$nfs_root/$sap_sid/SYS $sap_dir/SYS nfs defaults 0 0' >> /etc/fstab");
        assert_script_run('mount -a');
        assert_script_run("chmod -Rv 777 /sapmnt/");
        assert_script_run("chmod -Rv 777 $sap_dir/");
    }
}
1;
