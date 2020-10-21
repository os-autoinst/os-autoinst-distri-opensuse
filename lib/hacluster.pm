# SUSE's openQA tests
# Copyright (c) 2016-2019 SUSE LLC
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
use isotovideo;
use x11utils 'ensure_unlocked_desktop';

our @EXPORT = qw(
  $crm_mon_cmd
  $softdog_timeout
  $join_timeout
  $default_timeout
  exec_csync
  add_file_in_csync
  get_cluster_name
  get_hostname
  get_ip
  get_my_ip
  get_node_to_join
  get_node_number
  is_node
  add_to_known_hosts
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
  wait_until_resources_started
  get_lun
  check_device_available
  set_lvm_config
  add_lock_mgr
  pre_run_hook
  post_run_hook
  post_fail_hook
  test_flags
  is_not_maintenance_update
  activate_ntp
);

# Global variables
our $crm_mon_cmd     = 'crm_mon -R -r -n -N -1';
our $softdog_timeout = bmwqemu::scale_timeout(60);
our $prev_console;
our $join_timeout    = bmwqemu::scale_timeout(60);
our $default_timeout = bmwqemu::scale_timeout(30);

sub exec_csync {
    # Sometimes we need to run csync2 twice to have all the files updated!
    assert_script_run 'csync2 -vxF ; sleep 2 ; csync2 -vxF';
}

sub add_file_in_csync {
    my %args      = @_;
    my $conf_file = $args{conf_file} // '/etc/csync2/csync2.cfg';

    if (defined($conf_file) && defined($args{value})) {
        # Check if conf_file is a valid value
        assert_script_run "[[ -w $conf_file ]]";

        # Add the value in conf_file and sync on all nodes
        assert_script_run "grep -Fq $args{value} $conf_file || sed -i 's|^}\$|include $args{value};\\n}|' $conf_file";
        exec_csync;
    }

    return 1;
}

sub get_cluster_name {
    return get_required_var('CLUSTER_NAME');
}

sub get_hostname {
    return get_required_var('HOSTNAME');
}

sub get_node_to_join {
    return get_required_var('HA_CLUSTER_JOIN');
}

sub _just_the_ip {
    my $node_ip = shift;
    if ($node_ip =~ /(\d+\.\d+\.\d+\.\d+)/) {
        return $1;
    }
    return 0;
}

sub get_ip {
    my $node_hostname = shift;
    my $node_ip       = get_var('USE_SUPPORT_SERVER') ? script_output "host -t A $node_hostname" :
      script_output "awk 'BEGIN {RET=1} /$node_hostname/ {print \$1; RET=0; exit} END {exit RET}' /etc/hosts";
    return _just_the_ip($node_ip);
}

sub get_my_ip {
    my $netdevice = get_var('SUT_NETDEVICE', 'eth0');
    my $node_ip   = script_output "ip -4 addr show dev $netdevice | sed -rne '/inet/s/[[:blank:]]*inet ([0-9\\.]*).*/\\1/p'";
    return _just_the_ip($node_ip);
}

sub get_node_number {
    my $index = is_sle('15-sp2+') ? 2 : 1;
    return script_output "crm_mon -1 | awk '/ nodes configured/ { print \$$index }'";
}

sub is_node {
    my $node_number = shift;
    my $hostname    = get_hostname;

    # Node number must be coded with 2 digits
    $node_number = sprintf("%02d", $node_number);

    # Return true if HOSTNAME contains $node_number at his end
    return ($hostname =~ /$node_number$/);
}

sub add_to_known_hosts {
    my $host_to_add = shift;
    assert_script_run "mkdir -p ~/.ssh";
    assert_script_run "chmod 700 ~/.ssh";
    assert_script_run "ssh-keyscan -H $host_to_add >> ~/.ssh/known_hosts";
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
    script_run 'yes | crm configure show', $default_timeout;
    assert_script_run "$crm_mon_cmd",      $default_timeout;
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
    my $starttime = time;
    my $ret       = undef;

    while ($ret = script_run "ps -A | grep -q '\\<$process\\>'") {
        my $timerun = time - $starttime;
        if ($timerun < $default_timeout) {
            sleep 5;
        }
        else {
            die "Process '$process' did not start within $default_timeout seconds";
        }
    }

    # script_run need to be defined to ensure a correct exit code
    return defined $ret;
}

sub ensure_resource_running {
    my ($rsc, $regex) = @_;
    my $starttime = time;
    my $ret       = undef;

    while ($ret = script_run("crm resource status $rsc | grep -E -q '$regex'", $default_timeout)) {
        my $timerun = time - $starttime;
        if ($timerun < $default_timeout) {
            sleep 5;
        }
        else {
            die "Resource '$rsc' did not start within $default_timeout seconds";
        }
    }

    # script_run need to be defined to ensure a correct exit code
    return defined $ret;
}

sub ensure_dlm_running {
    die 'dlm is not running' unless check_rsc "dlm";
    return ensure_process_running 'dlm_controld';
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
    my $iscsi_devs    = '/tmp/iscsi_devices.list';
    my $mdadm_conf    = '/etc/mdadm.conf';
    my $clustername   = get_cluster_name;
    my $report_opt    = !is_sle('12-sp4+') ? '-f0' : '';
    my $cts_log       = '/tmp/cts_cluster_exerciser.log';
    my @y2logs;

    select_console 'root-console';

    # Extract HA logs and upload them
    script_run "touch $corosync_conf";
    script_run "hb_report $report_opt -E $bootstrap_log $hb_log", 300;
    upload_logs("$bootstrap_log",  failok => 1);
    upload_logs("$hb_log.tar.bz2", failok => 1);

    script_run "crm configure show > /tmp/crm.txt";
    upload_logs('/tmp/crm.txt');

    # Extract YaST logs and upload them
    script_run 'save_y2logs /tmp/y2logs.tar.bz2', 120;
    upload_logs('/tmp/y2logs.tar.bz2', failok => 1);

    # Generate the packages list
    script_run "rpm -qa > $packages_list";
    upload_logs("$packages_list", failok => 1);

    # iSCSI devices and their real paths
    script_run "ls -l /dev/disk/by-path/ > $iscsi_devs";
    upload_logs($iscsi_devs, failok => 1);

    # mdadm conf
    script_run "touch $mdadm_conf";
    upload_logs($mdadm_conf, failok => 1);

    # supportconfig
    script_run "supportconfig -g -B $clustername", 180;
    upload_logs("/var/log/nts_$clustername.tgz", failok => 1);

    # pacemaker cts log
    upload_logs($cts_log, failok => 1) if (get_var('PACEMAKER_CTS_TEST_ROLE'));

    # HAWK test logs if present
    upload_logs("/tmp/hawk_test.log", failok => 1);
    upload_logs("/tmp/hawk_test.ret", failok => 1);

    # HANA hdbnsutil logs
    if (check_var('CLUSTER_NAME', 'hana')) {
        script_run 'tar -zcf /tmp/trace.tgz $(find /hana/shared -name nameserver_*.trc)';
        upload_logs('/tmp/trace.tgz', failok => 1);
    }
}

sub check_cluster_state {
    assert_script_run "$crm_mon_cmd";
    assert_script_run "$crm_mon_cmd | grep -i 'no inactive resources'" if is_sle '12-sp3+';
    assert_script_run 'crm_mon -1 | grep \'partition with quorum\'';
    # In older versions, node names in crm node list output are followed by ": normal". In newer ones by ": member"
    assert_script_run q/crm_mon -s | grep "$(crm node list | egrep -c ': member|: normal') nodes online"/;
    # As some options may be deprecated, test shouldn't die on 'crm_verify'
    if (get_var('HDDVERSION')) {
        script_run 'crm_verify -LV';
    }
    else {
        assert_script_run 'crm_verify -LV';
    }
}

# Wait for resources to be started
# If changing this, remember to also change wait_until_resources_started in tests/publiccloud/sles4sap.pm
sub wait_until_resources_started {
    my %args    = @_;
    my @cmds    = ('crm cluster wait_for_startup');
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $ret     = undef;

    # Some CRM options can only been added on recent versions
    push @cmds, "$crm_mon_cmd | grep -iq 'no inactive resources'"                           if is_sle '12-sp3+';
    push @cmds, "! ($crm_mon_cmd | grep -Eioq ':[[:blank:]]*failed|:[[:blank:]]*starting')" if is_sle '12-sp3+';

    # Execute each comnmand to validate that the cluster is running
    # This can takes time, so a loop is a good idea here
    foreach my $cmd (@cmds) {
        # Each command execution has its own timeout, so we need to reset the counter
        my $starttime = time;

        # Check for cluster/resources status and exit loop when needed
        while ($ret = script_run("$cmd", $default_timeout)) {
            # Otherwise wait a while if timeout is not reached
            my $timerun = time - $starttime;
            if ($timerun < $timeout) {
                sleep 5;
            }
            else {
                die "Cluster/resources did not start within $timeout seconds (cmd='$cmd')";
            }
        }

        # script_run need to be defined to ensure a correct exit code
        die 'Cluster/resources check did not exit properly' if !defined $ret;
    }
}

# This function returns the first available LUN
sub get_lun {
    my %args          = @_;
    my $hostname      = get_hostname;
    my $cluster_name  = get_cluster_name;
    my $lun_list_file = '/tmp/' . $cluster_name . '-lun.list';
    my $use_once      = $args{use_once} // 1;
    my $supportdir    = get_var('NFS_SUPPORT_DIR', '/mnt');

    # Use mutex to be sure that only *one* node at a time can access the file
    mutex_lock 'iscsi';

    # Get the LUN file from the support server to have an up-to-date version
    if (get_var('USE_SUPPORT_SERVER')) {
        exec_and_insert_password "scp -o StrictHostKeyChecking=no root\@ns:$lun_list_file $lun_list_file";
    }
    else {
        assert_script_run "cp $supportdir/$cluster_name-lun.list $lun_list_file";
    }

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
    if (get_var('USE_SUPPORT_SERVER')) {
        exec_and_insert_password "scp -o StrictHostKeyChecking=no $lun_list_file root\@ns:$lun_list_file";
    }
    else {
        assert_script_run "cp $lun_list_file $supportdir/$cluster_name-lun.list";
    }

    mutex_unlock 'iscsi';

    # Return the real path of the block device
    return $lun;
}

# This method checks for the presence of a device in the system for up to a defined timeout (defaults to 20seconds)
sub check_device_available {
    my ($dev, $tout) = @_;
    my $ret;
    my $tries = $tout ? int($tout / 2) : 10;

    die "Must provide a device for check_device_available" unless (defined $dev);

    while ($tries and $ret = script_run "ls -la $dev") {
        --$tries;
        sleep 2;
    }
    die "Test timed out while checking $dev"   unless (defined $ret);
    die "Nonexistent $dev after $tout seconds" unless ($tries > 0 or $ret == 0);
    return $ret;
}

sub set_lvm_config {
    my ($lvm_conf, %args) = @_;
    my $cmd;

    foreach my $param (keys %args) {
        $cmd = sprintf("sed -ie 's/^\\([[:blank:]]*%s[[:blank:]]*=\\).*/\\1 %s/' %s", $param, $args{$param}, $lvm_conf);
        assert_script_run $cmd;
    }

    script_run "grep -E '^[[:blank:]]*use_lvmetad|^[[:blank:]]*locking_type|^[[:blank:]]*use_lvmlockd' $lvm_conf";
}

sub add_lock_mgr {
    my ($lock_mgr) = @_;

    assert_script_run "EDITOR=\"sed -ie '\$ a primitive $lock_mgr ocf:heartbeat:$lock_mgr'\" crm configure edit";
    assert_script_run "EDITOR=\"sed -ie 's/^\\(group base-group.*\\)/\\1 $lock_mgr/'\" crm configure edit";

    # Wait to get clvmd/lvmlockd running on all nodes
    sleep 5;
}

sub pre_run_hook {
    my ($self) = @_;
    if (isotovideo::get_version() == 12) {
        $prev_console = $autotest::selected_console;
    } else {
        # perl -c will give a "only used once" message
        # here and this makes the travis ci tests fail.
        1 if defined $testapi::selected_console;
        $prev_console = $testapi::selected_console;
    }
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

sub is_not_maintenance_update {
    my $package = shift;
    # Allow to skip an openQA module if package is not targeted by maintenance update
    if (get_var('MAINTENANCE') && get_var('BUILD') !~ /$package/) {
        record_info('Skipped - MU', "$package test not needed here");
        return 1;
    }
    return 0;
}

sub activate_ntp {
    my $ntp_service = is_sle('15+') ? 'chronyd' : 'ntpd';
    systemctl "enable --now $ntp_service.service";
}

1;
