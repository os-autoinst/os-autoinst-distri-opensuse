# SUSE's openQA tests
# Copyright (c) 2016 SUSE LLC
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
# Summary: Functions for HA Cluster tests
# Maintainer: Loic Devulder <ldevulder@suse.com>

package hacluster;

use base Exporter;
use Exporter;
use strict;
use warnings;
use version_utils 'is_sle';
use utils;
use testapi;
use lockapi;

our @EXPORT = qw(
  $crm_mon_cmd
  $softdog_timeout
  get_cluster_name
  get_hostname
  get_node_to_join
  get_node_number
  is_node
  choose_node
  save_state
  is_package_installed
  check_rsc
  ensure_process_running
  ensure_resource_running
  ensure_dlm_running
  write_tag
  read_tag
  block_device_real_path
  lvm_add_filter
  lvm_remove_filter
  rsc_cleanup
  ha_export_logs
  check_cluster_state
  get_lun
  pre_run_hook
  post_run_hook
  post_fail_hook
  test_flags
);

# Global variables
our $crm_mon_cmd     = 'crm_mon -R -r -n -N -1';
our $softdog_timeout = 60;
our $prev_console;

sub get_cluster_name {
    return get_required_var('CLUSTER_NAME');
}

sub get_hostname {
    return get_required_var('HOSTNAME');
}

sub get_node_to_join {
    return get_required_var('HA_CLUSTER_JOIN');
}

sub get_node_number {
    return script_output 'crm_mon -1 | awk \'/ nodes configured/ { print $1 }\'';
}

sub is_node {
    my $node_number = shift;
    my $hostname    = get_hostname;

    # Node number must be coded with 2 digits
    $node_number = sprintf("%02d", $node_number);

    # Return true if HOSTNAME contains $node_number at his end
    return ($hostname =~ /$node_number$/);
}

sub choose_node {
    my $node_number  = shift;
    my $tmp_hostname = get_hostname;

    # Node number must be coded with 2 digits
    $node_number = sprintf("%02d", $node_number);

    # Replace the digit of HOSTNAME to create the new hostname
    $tmp_hostname =~ s/(.*)[0-9][0-9]$/$1$node_number/;

    # And return it
    return $tmp_hostname;
}

sub save_state {
    script_run 'yes | crm configure show';
    assert_script_run "$crm_mon_cmd";
    save_screenshot;
}

sub is_package_installed {
    my $package = shift;
    my $ret     = script_run "rpm -q $package";

    return (defined $ret and $ret == 0);
}

sub check_rsc {
    my $rsc = shift;
    my $ret = script_run "$crm_mon_cmd 2>/dev/null | grep -q '\\<$rsc\\>'";

    return (defined $ret and $ret == 0);
}

sub ensure_process_running {
    my $process   = shift;
    my $timeout   = 30;
    my $starttime = time;
    while (script_run "ps -A | grep -q '\\<$process\\>'") {
        my $timerun = time - $starttime;
        if ($timerun < $timeout) {
            sleep 5;
        }
        else {
            die "Process '$process' did not start within $timeout seconds";
        }
    }

    return 0;
}

sub ensure_resource_running {
    my ($rsc, $regex) = @_;
    my $timeout   = 30;
    my $starttime = time;
    while (script_run "crm resource status $rsc | grep -E -q '$regex'") {
        my $timerun = time - $starttime;
        if ($timerun < $timeout) {
            sleep 5;
        }
        else {
            die "Resource '$rsc' did not start within $timeout seconds";
        }
    }

    return 0;
}

sub ensure_dlm_running {
    die 'dlm is not running' unless check_rsc "dlm";
    ensure_process_running 'dlm_controld';

    return 0;
}

sub write_tag {
    my $tag     = shift;
    my $rsc_tag = '/tmp/' . get_cluster_name . '.rsc';
    my $ret     = script_run "echo $tag > $rsc_tag";

    return (defined $ret and $ret == 0);
}

sub read_tag {
    my $rsc_tag = '/tmp/' . get_cluster_name . '.rsc';

    return script_output "cat $rsc_tag 2>/dev/null";
}

sub block_device_real_path {
    my $lun = shift;

    return script_output "realpath -ePL $lun";
}

sub lvm_add_filter {
    my ($type, $filter) = @_;
    my $lvm_conf = '/etc/lvm/lvm.conf';

    assert_script_run "sed -ie '/^[[:blank:]][[:blank:]]*filter/s;\\[[[:blank:]]*;\\[ \"$type|$filter|\", ;' $lvm_conf";
}

sub lvm_remove_filter {
    my $filter   = shift;
    my $lvm_conf = '/etc/lvm/lvm.conf';

    assert_script_run "sed -ie '/^[[:blank:]][[:blank:]]*filter/s;$filter;;' $lvm_conf";
}

sub rsc_cleanup {
    my $rsc = shift;

    assert_script_run "crm resource cleanup $rsc";

    my $ret = script_run "crm_mon -1 2>/dev/null | grep -Eq \"$rsc.*'not configured'|$rsc.*exit\"";
    if (defined $ret and $ret == 0) {
        # Resource is not cleared, so we need to force cleanup
        # Record a soft failure for this, as a bug is opened
        record_soft_failure 'bsc#1071503';
        assert_script_run "crm_resource -R -r $rsc";
    }
}

sub ha_export_logs {
    my $bootstrap_log = '/var/log/ha-cluster-bootstrap.log';
    my $corosync_conf = '/etc/corosync/corosync.conf';
    my $hb_log        = '/var/log/hb_report';
    my $packages_list = '/tmp/packages.list';
    my $report_opt    = '-f0' unless is_sle('15+');
    my @y2logs;

    # Extract HA logs and upload them
    script_run "touch $corosync_conf";
    script_run "hb_report $report_opt -E $bootstrap_log $hb_log", 300;
    upload_logs "$bootstrap_log";
    upload_logs "$hb_log.tar.bz2";

    # Extract YaST logs and upload them
    script_run 'save_y2logs /tmp/y2logs.tar.bz2', 120;
    upload_logs '/tmp/y2logs.tar.bz2';

    # Generate the packages list
    script_run "rpm -qa > $packages_list";
    upload_logs "$packages_list";
}

sub check_cluster_state {
    assert_script_run "$crm_mon_cmd";
    assert_script_run 'crm_mon -1 | grep \'partition with quorum\'';
    assert_script_run 'crm_mon -s | grep "$(crm node list | wc -l) nodes online"';
}

# This function returns the first available LUN
sub get_lun {
    my %args          = @_;
    my $hostname      = get_hostname;
    my $lun_list_file = '/tmp/' . get_cluster_name . '-lun.list';
    my $use_once      = $args{use_once} // 1;

    # Use mutex to be sure that only *one* node at a time can access the file
    mutex_lock 'iscsi';

    # Get the LUN file from the support server to have an up-to-date version
    exec_and_insert_password "scp -o StrictHostKeyChecking=no root\@ns:$lun_list_file $lun_list_file";

    # Extract the first *free* line for this server
    my $lun = script_output "grep -Fv '$hostname' $lun_list_file | awk 'NR==1 { print \$1 }'";

    # Die if no LUN is found
    die "No LUN found in $lun_list_file" if (!length $lun);

    if ($use_once) {
        # Remove LUN if needed
        my $tmp_lun = $lun;
        $tmp_lun =~ s/\//\\\//g;
        assert_script_run "sed -i '/$tmp_lun/d' $lun_list_file";
    }
    else {
        # Add the hostname as a tag in the LUN file
        # So in next call, get_lun will not return this LUN for this host
        assert_script_run "sed -i -E 's;^($lun([[:blank:]]|\$).*);\\1 $hostname;' $lun_list_file";
    }

    # Copy the modified file on the support server (for the other nodes)
    exec_and_insert_password "scp -o StrictHostKeyChecking=no $lun_list_file root\@ns:$lun_list_file";

    mutex_unlock 'iscsi';

    # Return the real path of the block device
    return block_device_real_path "$lun";
}

sub pre_run_hook {
    my ($self) = @_;

    $prev_console = $testapi::selected_console;
}

sub post_run_hook {
    my ($self) = @_;

    return unless ($prev_console);
    select_console($prev_console, await_console => 0);
    if ($prev_console eq 'x11') {
        ensure_unlocked_desktop;
    }
    else {
        $self->clear_and_verify_console;
    }
}

sub post_fail_hook {
    my ($self) = @_;

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    ha_export_logs;
    $self->export_logs;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
# vim: set sw=4 et:
