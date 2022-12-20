# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: corosync pacemaker
# Summary: Configure shared NFS mount point and /etc/hosts for HA
#          tests with no supportserver
# Maintainer: QE-SAP <qe-sap@suse.de>, Alvaro Carvajal <acarvajal@suse.com>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use lockapi;
use utils qw(systemctl file_content_replace);
use hacluster qw(get_cluster_name get_hostname get_ip get_my_ip is_node choose_node exec_csync);

sub replace_text_in_ha_files {
    my %changes = @_;
    my @files_to_fix = qw(/etc/corosync/corosync.conf /etc/drbd.d/drbd_passive.res);

    foreach my $file (@files_to_fix) {
        file_content_replace($file, %changes);
        assert_script_run "cat $file";
    }
}

sub run {
    my $nfs_share = get_required_var('NFS_SUPPORT_SHARE');
    my $mountpt = '/support_fs';
    my $cluster_name = get_cluster_name;
    my $build = join('_', get_required_var('BUILD') =~ m/(\w+)/g);
    my $dir_id = join('_', $cluster_name, get_required_var('VERSION'), get_required_var('ARCH'), $build);
    my $testname = get_required_var('TEST');
    my $time_to_wait;

    # If dealing with upgrades, specify that in the directory name as to avoid overwriting info
    # from other running tests
    $testname =~ s/@.+$//;
    $testname =~ s/_node\d+$//;
    $dir_id .= "_$testname" if get_var('HDDVERSION', '');

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
    my $ipaddr = get_my_ip;
    assert_script_run "echo \"$ipaddr  $hostname\" > $mountpt/$dir_id/$hostname.hosts";

    barrier_wait("BARRIER_HA_HOSTS_FILES_READY_$cluster_name");
    assert_script_run "sed -i '/$cluster_name/d' /etc/hosts";
    assert_script_run "cat $mountpt/$dir_id/*.hosts >> /etc/hosts";
    assert_script_run 'cat /etc/hosts';

    # Special tasks to do in upgrades
    if (get_var('HDDVERSION', '')) {
        # Ensure cluster is not running
        systemctl 'stop pacemaker corosync';

        # Get IP addresses configured in /etc/corosync.conf
        my %addr_changes = ();
        my $old_addr = script_output q(grep ring0 /etc/corosync/corosync.conf | awk '{print "ip:"$2}' | uniq | tr '\n' ',');
        my $count = 0;

        foreach my $addr (split(/,/, $old_addr)) {
            ++$count;
            $addr =~ /ip:([\d\.]+)/;
            $addr_changes{$1} = "%NODE$count%";
        }

        # Finish early if no ring0 addresses were found in corosync.conf.
        if ($count == 0) {
            systemctl 'start corosync pacemaker';
            return;
        }

        # Apply workaround only in node 1 and then sync files
        if (is_node(1)) {
            # Remove old addresses from HA conf files
            replace_text_in_ha_files(%addr_changes);

            # Get current IP address for the nodes. $ipaddr already has the info for the current node,
            # and $count has the number of old IP address in corosync.conf
            %addr_changes = (q(%NODE1%) => $ipaddr);
            my $total_nodes = $count;
            for ($count = 2; $count <= $total_nodes; $count++) {
                my $partnerip = get_ip choose_node($count);
                $addr_changes{"%NODE$count%"} = $partnerip;
            }

            # Replace new IP addresses in HA conf files and sync files to other node
            replace_text_in_ha_files(%addr_changes);
            exec_csync;
        }

        # Restart cluster
        barrier_wait("BARRIER_HA_NONSS_FILES_SYNCED_$cluster_name");
        systemctl 'start corosync pacemaker';
        return;    # Skip LUN setup in upgrades
    }

    # prepare LUN files. only node 1 does this
    if (is_node(1)) {
        my $cluster = get_required_var('CLUSTER_INFOS');
        my $iscsi_srv = get_required_var('ISCSI_SERVER');
        my $num_luns = (split(/:/, $cluster))[2];
        my $lun_list_file = "$mountpt/$dir_id/$cluster_name-lun.list";
        my $index = get_var('ISCSI_LUN_INDEX', 0);

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
