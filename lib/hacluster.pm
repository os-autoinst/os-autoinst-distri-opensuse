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
use version_utils 'is_sle';
use warnings;
use testapi;

our @EXPORT = qw(
  $cluster_name
  $crm_mon_cmd
  $softdog_timeout
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
  check_cluster_state
  ha_export_logs
  post_run_hook
  post_fail_hook
  test_flags
);

# Global variables
our $cluster_name    = get_var('CLUSTER_NAME');
our $crm_mon_cmd     = 'crm_mon -R -r -n -N -1';
our $softdog_timeout = 60;

sub get_node_number {
    return script_output 'crm_mon -1 | awk \'/ nodes configured/ { print $1 }\'';
}

sub is_node {
    my $node_number = shift;

    # Node number must be coded with 2 digits
    $node_number = sprintf("%02d", $node_number);

    # Return true if HOSTNAME contains $node_number at his end
    return (get_var('HOSTNAME') =~ /$node_number$/);
}

sub choose_node {
    my $node_number  = shift;
    my $tmp_hostname = get_var('HOSTNAME');

    # Node number must be coded with 2 digits
    $node_number = sprintf("%02d", $node_number);

    # Replace the digit of HOSTNAME to create the new hostname
    $tmp_hostname =~ s/([a-z]*).*$/$1$node_number/;

    # And return it
    return ($tmp_hostname);
}

sub save_state {
    script_run 'yes | crm configure show';
    assert_script_run "$crm_mon_cmd";
    save_screenshot;
}

sub is_package_installed {
    my $package = shift;

    return (!script_run "rpm -q $package");
}

sub check_rsc {
    my $rsc = shift;

    # As Perl and Shell do not handle return code as the same way,
    # we need to invert it
    return (!script_run "$crm_mon_cmd 2>/dev/null | grep -q '\\<$rsc\\>'");
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
    my $rsc_tag = '/tmp/' . get_var('CLUSTER_NAME') . '.rsc';

    return (!script_run "echo $tag > $rsc_tag");
}

sub read_tag {
    my $rsc_tag = '/tmp/' . get_var('CLUSTER_NAME') . '.rsc';

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
    if (!script_run "crm_mon -1 2>/dev/null | grep -Eq \"$rsc.*'not configured'|$rsc.*exit\"") {
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
    select_console 'root-console';
    script_run "touch $corosync_conf";
    script_run "hb_report $report_opt -E $bootstrap_log $hb_log", 120;
    upload_logs "$bootstrap_log";
    upload_logs "$hb_log.tar.bz2";

    # Extract YaST logs and upload them
    script_run "save_y2logs", 120;

    # Generate the packages list
    script_run "rpm -qa > $packages_list";
    upload_logs "$packages_list";

    # We can find multiple y2log files
    push @y2logs, script_output 'ls /tmp/y2log-*.tar.xz';
    foreach my $y2log (@y2logs) {
        upload_logs "$y2log";
    }
}

sub check_cluster_state {
    assert_script_run "$crm_mon_cmd";
    assert_script_run 'crm_mon -1 | grep \'partition with quorum\'';
    assert_script_run 'crm_mon -s | grep "$(crm node list | wc -l) nodes online"';
}

sub post_run_hook {
    my ($self) = @_;

    # Clear screen to make screen content ready for next test
    $self->clear_and_verify_console;
}

sub post_fail_hook {
    my $self = shift;

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
