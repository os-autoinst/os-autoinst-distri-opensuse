# SUSE's SLES4SAP openQA tests

#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure NetWeaver filesystems
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.de>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'systemctl';
use hacluster;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    my $type = get_required_var('INSTANCE_TYPE');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sid = get_required_var('INSTANCE_SID');
    my $arch = get_required_var('ARCH');
    my $lun = get_lun;
    my $sap_dir = "/usr/sap/$sid";
    my ($proto, $path) = $self->fix_path(get_required_var('NW'));

    # LUN information is needed after for the HA configuration
    set_var('INSTANCE_LUN', "$lun");

    select_serial_terminal;

    # Create/format/mount local filesystems
    assert_script_run "mkfs -t xfs -f \"$lun\"";
    assert_script_run "mkdir -p $sap_dir/${type}${instance_id}";
    assert_script_run "mount \"$lun\" $sap_dir/${type}${instance_id}";
    assert_script_run "chmod 0777 \"$lun\" $sap_dir/${type}${instance_id}";

    # Mount NFS filesystem
    assert_script_run "echo '$path/$arch/nfs_share/sapmnt /sapmnt $proto defaults,bg 0 0' >> /etc/fstab";
    assert_script_run "echo '$path/$arch/nfs_share/usrsapsys $sap_dir/SYS $proto defaults,bg 0 0' >> /etc/fstab";
    systemctl 'enable nfs';
    systemctl 'start nfs';
    foreach my $mountpoint ('/sapmnt', "$sap_dir/SYS") {
        assert_script_run "mkdir -p $mountpoint && mount $mountpoint";

        # NFS mounts need to be cleared before the NW installation
        assert_script_run "rm -rf $mountpoint/*";
    }
}

1;
