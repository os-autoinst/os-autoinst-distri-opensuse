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
use testapi;

our @EXPORT = qw(
  $cluster_name
  $crm_mon_cmd
  $softdog_timeout
  get_node_number
  is_node
  choose_node
  show_rsc
  save_state
  is_package_installed
  ensure_process_running
  ensure_resource_running
  check_rsc
  write_tag
  read_tag
  block_device_real_path
  lvm_add_filter
  lvm_remove_filter
  ha_export_logs
  post_run_hook
  post_fail_hook
  test_flags
);

# Global variables
our $cluster_name    = get_var('CLUSTER_NAME');
our $crm_mon_cmd     = 'crm_mon -R -r -n -N -1';
our $softdog_timeout = 60;

# Get the number of nodes
sub get_node_number {
    return script_output 'crm_mon -1 | awk \'/ nodes configured/ { print $1 }\'';
}

# Check if we are on $node_number
sub is_node {
    my $node_number = shift;

    # Node number must be coded with 2 digits
    $node_number = sprintf("%02d", $node_number);

    # Return true if HOSTNAME contains $node_number at his end
    return (get_var('HOSTNAME') =~ /$node_number$/);
}

# Get the name of node based on his number
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

# Show the cluster resource
sub show_rsc {
    script_run 'yes | crm configure show';
    save_screenshot;
}

# Print the state of the cluster and do a screenshot
sub save_state {
    script_run "$crm_mon_cmd";
    save_screenshot;
}

sub is_package_installed {
    my $package = shift;

    return (!script_run "rpm -q $package");
}

sub is_process_running {
    my $process  = shift;
    my $ret_code = 0;

    for (1 .. 10) {
        if (!script_run "ps -A | grep -q '\\<$process\\>'") {
            $ret_code = 1;
            last;
        }
        sleep 2;
    }

    return $ret_code;
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
# Check if a resource exists
sub check_rsc {
    my $rsc = shift;

    # As Perl and Shell do not handle return code as the same way,
    # we need to invert it
    return (!script_run "$crm_mon_cmd 2>/dev/null | grep -q '\\<$rsc\\>'");
}

# Add the tag for resource configuration
sub write_tag {
    my $tag     = shift;
    my $rsc_tag = '/tmp/' . get_var('CLUSTER_NAME') . '.rsc';

    return (!script_run "echo $tag > $rsc_tag");
}

# Get the tag for resource configuration
sub read_tag {
    my $rsc_tag = '/tmp/' . get_var('CLUSTER_NAME') . '.rsc';

    return script_output "cat $rsc_tag 2>/dev/null";
}

# Return the *real* device path
sub block_device_real_path {
    my $lun = shift;

    return script_output "realpath -ePL $lun";
}

# Add a filter entry in lvm.conf
sub lvm_add_filter {
    my ($type, $filter) = @_;
    my $lvm_conf = '/etc/lvm/lvm.conf';

    assert_script_run "sed -ie '/^[[:blank:]][[:blank:]]*filter/s;\\[[[:blank:]]*;\\[ \"$type|$filter|\", ;' $lvm_conf";
}

# Remove a filter entry from lvm.conf
sub lvm_remove_filter {
    my $filter   = shift;
    my $lvm_conf = '/etc/lvm/lvm.conf';

    assert_script_run "sed -ie '/^[[:blank:]][[:blank:]]*filter/s;$filter;;' $lvm_conf";
}

sub ha_export_logs {
    my $bootstrap_log = '/var/log/ha-cluster-bootstrap.log';
    my $corosync_conf = '/etc/corosync/corosync.conf';
    my $hb_log        = 'hb_report';

    # Extract HA logs and upload them
    select_console 'root-console';
    upload_logs "$bootstrap_log";
    script_run "touch $corosync_conf";
    script_run "hb_report -E $bootstrap_log $hb_log", 120;
    upload_logs "$hb_log.tar.bz2" if !script_run "test -e $hb_log";
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
