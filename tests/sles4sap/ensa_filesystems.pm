# SUSE's SLES4SAP openQA tests

#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure NetWeaver filesystems for ENSA2 based installation
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use strict;
use warnings;
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(systemctl file_content_replace);
use hacluster;
use lockapi;

sub run {
    my ($self) = @_;
    my $nfs_root = get_required_var('NFS_MOUNT');
    my $nw_install_data = $self->netweaver_installation_data();
    my $create_directories = join(',', 'sapmnt', 'SYS');
    my $sap_sid = $nw_install_data->{instance_sid};
    my $sap_dir = $nw_install_data->{sap_directory};

    select_serial_terminal;

    # Setup NFS directory structure on supportserver side
    if (check_var('SUPPORT_SERVER', '1')) {
        my $nfs_permissions = get_required_var("NFS_PERMISSIONS");
        record_info('NFS prep', 'Preparing SAP related exports');

        assert_script_run("mkdir -p $nfs_root/$sap_sid/{$create_directories}");
        # assert_script_run("chmod -Rv 777 $nfs_root/$sap_sid");
        # assert_script_run("chown -Rv $sidadm_uid:$sapsys_guid $nfs_root/$sap_sid/*");
        assert_script_run("echo $nfs_root *\($nfs_permissions\) >> /etc/exports");
        assert_script_run("exportfs -r");
        systemctl("restart nfs-server");
        systemctl("restart rpcbind");
        systemctl("is-active nfs-server -a rpcbind");
        return;
    }

    # Mount shared SAP  NFS filesystems
    record_info('NFS mounts', 'Preparing shared NFS filesystems');
    assert_script_run("mkdir -p /sapmnt $sap_dir/{$create_directories}");
    assert_script_run("echo 'ns:$nfs_root/$sap_sid/sapmnt /sapmnt nfs defaults 0 0' >> /etc/fstab");
    assert_script_run("echo 'ns:$nfs_root/$sap_sid/SYS $sap_dir/SYS nfs defaults 0 0' >> /etc/fstab");
    assert_script_run('mount -a');
    assert_script_run("chmod -Rv 777 /sapmnt/");
    assert_script_run("chmod -Rv 777 $sap_dir/");

    # Prepare and mount ISCSI devices
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $instance_dir = $nw_install_data->{instances}{$instance_type}{instance_dir_name};
    set_var('INSTANCE_ID', $nw_install_data->{instances}{$instance_type}{instance_id});

    if ($instance_type eq 'ASCS') {
        record_info('ISCSI mounts', 'Preparing shared NFS filesystems');
        my $lun_path = get_lun(use_once => 0);    # ERS will use the same LUN.
        set_var('USR_SAP_DEVICE_ASCS', "$lun_path-part1");    # save it in variable for other modules
        set_var('USR_SAP_DEVICE_ERS', "$lun_path-part2");    # save it in variable for other modules
        assert_script_run("mkdir -p $sap_dir/$instance_dir");
        assert_script_run("parted -s $lun_path mklabel gpt");
        assert_script_run("parted -s $lun_path mkpart primary 0% 50%");
        assert_script_run("parted -s $lun_path mkpart primary 50% 100%");
        assert_script_run("mkfs.xfs $lun_path-part1");
        assert_script_run("mkfs.xfs $lun_path-part2");
        assert_script_run("mount $lun_path-part1 $sap_dir/$instance_dir");
        assert_script_run("chmod 777 $sap_dir/$instance_dir");
    }

    barrier_wait('ISCSI_LUN_PREPARE');    # ENSA needs to wait for partitioning being done
    if ($instance_type eq 'ERS') {
        my $lun_path = get_lun;    # ERS removes lun from the list.
        assert_script_run("partprobe; fdisk -l $lun_path");
        assert_script_run("mkdir -p $sap_dir/$instance_dir");
        assert_script_run("mount $lun_path-part2 $sap_dir/$instance_dir");
        assert_script_run("chmod 777 $sap_dir/$instance_dir");
    }
    record_info('Block devices', assert_script_run('lsblk'));
    record_info('Mounts', assert_script_run("mount | grep $sap_sid"));
    record_info('Usrsap dir', assert_script_run("ls -alitr $sap_dir"));
}

1;
