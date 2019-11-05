# SUSE's openQA tests
#
# Copyright (c) 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure shared NFS mount point and /etc/hosts for HA
#          tests with no supportserver
# Maintainer: Alvaro Carvajal <acarvajal@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use hacluster qw(get_cluster_name get_hostname get_my_ip is_node);

sub run {
    my $nfs_share    = get_required_var('NFS_SUPPORT_SHARE');
    my $mountpt      = '/support_fs';
    my $cluster_name = get_cluster_name;
    my $dir_id       = join('_', $cluster_name, get_required_var('VERSION'), get_required_var('ARCH'));
    my $hddversion   = get_var('HDDVERSION', '');
    my $time_to_wait;

    # If dealing with upgrades, specify that in the directory name as to avoid overwriting info
    # from other running tests
    $dir_id .= "_from_$hddversion" if $hddversion;

    set_var('NFS_SUPPORT_DIR', "$mountpt/$dir_id");
    assert_script_run "mkdir -p $mountpt";
    assert_script_run "mount -t nfs $nfs_share $mountpt";

    if (is_node(1)) {
        assert_script_run "rm -rf $mountpt/$dir_id";    # Remove info from previous test
        assert_script_run "mkdir -p $mountpt/$dir_id";
        barrier_wait("BARRIER_HA_NFS_SUPPORT_DIR_SETUP_$cluster_name");
    }
    else {
        barrier_wait("BARRIER_HA_NFS_SUPPORT_DIR_SETUP_$cluster_name");
    }

    my $hostname = get_hostname;
    my $ipaddr   = get_my_ip;
    assert_script_run "echo \"$ipaddr  $hostname\" > $mountpt/$dir_id/$hostname.hosts";

    barrier_wait("BARRIER_HA_HOSTS_FILES_READY_$cluster_name");
    assert_script_run "sed -i '/$cluster_name/d' /etc/hosts";
    assert_script_run "cat $mountpt/$dir_id/*.hosts >> /etc/hosts";
    assert_script_run 'cat /etc/hosts';

    # Skip LUN setup in upgrades
    return if $hddversion;

    # prepare LUN files. only node 1 does this
    if (is_node(1)) {
        my $cluster       = get_required_var('CLUSTER_INFOS');
        my $iscsi_srv     = get_required_var('ISCSI_SERVER');
        my $num_luns      = (split(/:/, $cluster))[2];
        my $lun_list_file = "$mountpt/$dir_id/$cluster_name-lun.list";
        my $index         = get_var('ISCSI_LUN_INDEX', 0);

        assert_script_run "rm -f $lun_list_file ; touch $lun_list_file";

        if (defined $num_luns) {
            foreach my $i (0 .. ($num_luns - 1)) {
                my $lun = "/dev/disk/by-path/ip-$iscsi_srv*-lun-" . ($i + $index);
                assert_script_run "ls $lun >> $lun_list_file";
                $lun = script_output 'echo \|$(ls ' . $lun . ')\|';
                $lun =~ /\|([^\|]+)\|/;
                $lun = $1;
                assert_script_run "wipefs --all $lun";
                assert_script_run "dd if=/dev/zero of=$lun bs=1M count=128";
            }
        }

        assert_script_run "cat $lun_list_file";
    }

    barrier_wait("BARRIER_HA_LUNS_FILES_READY_$cluster_name");
}

# Override post_fail hook so it doesn't call ha_export_logs
sub post_fail_hook {
    my ($self) = @_;
    save_screenshot;
}

1;
