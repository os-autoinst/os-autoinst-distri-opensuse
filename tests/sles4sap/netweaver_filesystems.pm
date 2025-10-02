# SUSE's SLES4SAP openQA tests

#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure NetWeaver filesystems
# Maintainer: QE-SAP <qe-sap@suse.de>, Loic Devulder <ldevulder@suse.de>

use base 'sles4sap';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'systemctl';
use hacluster;
use version_utils qw(is_sle);

sub run {
    my ($self) = @_;
    my $type = get_required_var('INSTANCE_TYPE');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sid = get_required_var('INSTANCE_SID');
    my $arch = get_required_var('ARCH');
    my $lun = get_lun;
    my $sap_dir = "/usr/sap/$sid";
    my ($proto, $path) = $self->fix_path(get_required_var('NW'));
    my $nfs_client_service_name = is_sle('16+') ? 'nfs-client.target' : 'nfs.service';
    # The following lines use TEST, VERSION and FLAVOR to calculate a dir name for nfs shares.
    # The job TEST names include *_supportserver, *_node01 and _node02, which are removed
    # in order to get the same name for all nodes.
    my $test_name = get_required_var('TEST');
    $test_name =~ s/_(?:node\d+|supportserver)\z//i;
    my $subdir = join '_', $test_name, get_required_var('FLAVOR'), get_required_var('VERSION');
    $subdir =~ s/[^A-Za-z0-9._-]+/_/g;
    my $sapmnt_base = "$path/$arch/nfs_share/sapmnt";
    my $usrsapsys_base = "$path/$arch/nfs_share/usrsapsys";

    # LUN information is needed after for the HA configuration
    set_var('INSTANCE_LUN', "$lun");

    select_serial_terminal;

    # Create/format/mount local filesystems
    assert_script_run "mkfs -t xfs -f \"$lun\"";
    assert_script_run "mkdir -p $sap_dir/${type}${instance_id}";
    assert_script_run "mount \"$lun\" $sap_dir/${type}${instance_id}";
    assert_script_run "chmod 0777 \"$lun\" $sap_dir/${type}${instance_id}";

    # Mount NFS filesystem
    systemctl "enable $nfs_client_service_name";
    systemctl "start $nfs_client_service_name";

    assert_script_run "mkdir -p /sapmnt '$sap_dir/SYS'";
    assert_script_run "mount -t $proto '$sapmnt_base' /sapmnt && mkdir -p /sapmnt/'$subdir' && umount /sapmnt";
    # chmod -R 0777 added to avoid "error 13" during installation, as per SAP KB: https://me.sap.com/notes/0002589600
    assert_script_run "mount -t $proto '$usrsapsys_base' '$sap_dir/SYS' && mkdir -p '$sap_dir/SYS/$subdir' && chmod -R 0777 $sap_dir && umount '$sap_dir/SYS'";
    assert_script_run "echo '$sapmnt_base/$subdir /sapmnt $proto defaults,bg 0 0' >> /etc/fstab";
    assert_script_run "echo '$usrsapsys_base/$subdir $sap_dir/SYS $proto defaults,bg 0 0' >> /etc/fstab";

    foreach my $mountpoint ('/sapmnt', "$sap_dir/SYS") {
        assert_script_run "mkdir -p $mountpoint && mount $mountpoint";

        # NFS mounts need to be cleared before the NW installation
        # Do this only in node 1
        assert_script_run "rm -rf $mountpoint/*" if (is_node(1));
    }
}

1;
