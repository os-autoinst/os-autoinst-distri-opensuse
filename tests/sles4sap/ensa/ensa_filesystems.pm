# SUSE's SLES4SAP openQA tests

#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure NetWeaver filesystems for ENSA2 based installation
# Maintainer: QE-SAP <qe-sap@suse.de>

use base 'sles4sap';
use testapi;
use serial_terminal qw(select_serial_terminal);
use utils qw(systemctl file_content_replace script_retry);
use hacluster;
use lockapi;

sub run {
    my ($self) = @_;
    my $nw_install_data = $self->netweaver_installation_data();
    my $sap_sid = $nw_install_data->{instance_sid};
    my $sap_dir = $nw_install_data->{sap_directory};

    select_serial_terminal;

    # Prepare and mount ISCSI devices
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $instance_dir = $nw_install_data->{instances}{$instance_type}{instance_dir_name};
    set_var('INSTANCE_ID', $nw_install_data->{instances}{$instance_type}{instance_id});

    if ($instance_type eq 'ASCS') {
        my $lun_path = get_lun(use_once => 0);    # ERS will use the same LUN.
        set_var('USR_SAP_DEVICE_ASCS', "$lun_path-part1");    # save it in variable for other modules
        set_var('USR_SAP_DEVICE_ERS', "$lun_path-part2");    # save it in variable for other modules

        # Create the partitions
        assert_script_run("mkdir -p $sap_dir/$instance_dir");
        assert_script_run("parted -s $lun_path --list");
        # From the manual: changes will *probably* be made to the disk
        # immediately after typing a command. However, the operating system’s
        # cache and the disk’s hardware cache may delay this. When using serial
        # we hit this limitation, to avoid that we run udevadm settle and parted again.
        assert_script_run("udevadm settle --timeout=$default_timeout", $default_timeout + 5);
        assert_script_run("parted -s $lun_path mklabel gpt");
        assert_script_run("udevadm settle --timeout=$default_timeout", $default_timeout + 5);
        assert_script_run("parted -s $lun_path mkpart primary 0% 50%");
        assert_script_run("udevadm settle --timeout=$default_timeout", $default_timeout + 5);
        assert_script_run("parted -s $lun_path mkpart primary 50% 100%");
        assert_script_run("udevadm settle --timeout=$default_timeout", $default_timeout + 5);
        assert_script_run("parted -s $lun_path --list");

        # Format the partitions
        script_retry("mkfs.xfs $lun_path-part1", delay => 5, retry => 3);
        assert_script_run("udevadm settle --timeout=$default_timeout", $default_timeout + 5);
        script_retry("mkfs.xfs $lun_path-part2", delay => 5, retry => 3);
        assert_script_run("udevadm settle --timeout=$default_timeout", $default_timeout + 5);
        assert_script_run("fdisk -l");
        assert_script_run("mount -t xfs $lun_path-part1 $sap_dir/$instance_dir");
        assert_script_run("chmod 777 $sap_dir/$instance_dir");
        assert_script_run("udevadm settle --timeout=$default_timeout", $default_timeout + 5);
    }

    # ENSA needs to wait for partitioning being done
    barrier_wait('ISCSI_LUN_PREPARE');

    if ($instance_type eq 'ERS') {
        my $lun_path = get_lun;    # ERS removes lun from the list.
        assert_script_run("fdisk -l $lun_path");
        assert_script_run("mkdir -p $sap_dir/$instance_dir");
        script_run('partprobe');
        script_retry("mount -t xfs $lun_path-part2 $sap_dir/$instance_dir", delay => 10, retry => 3);
        assert_script_run("chmod 777 $sap_dir/$instance_dir");
    }
    record_info('Block devices', assert_script_run('lsblk'));
    record_info('Mounts', assert_script_run("mount | grep $sap_sid"));
    record_info('Usrsap dir', assert_script_run("ls -alitr $sap_dir"));
}

1;
