# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for HA Cluster tests

package hacluster;

use base Exporter;
use Exporter;
use strict;
use warnings;
use version_utils 'is_sle';
use Scalar::Util 'looks_like_number';
use utils;
use testapi;
use lockapi;
use isotovideo;
use x11utils 'ensure_unlocked_desktop';
use Utils::Logging 'export_logs';
use Carp qw(croak);
use Data::Dumper;

our @EXPORT = qw(
  $crm_mon_cmd
  $softdog_timeout
  $join_timeout
  $default_timeout
  $corosync_token
  $corosync_consensus
  $sbd_watchdog_timeout
  $sbd_delay_start
  $pcmk_delay_max
  exec_csync
  add_file_in_csync
  get_cluster_name
  get_hostname
  get_ip
  get_my_ip
  get_node_to_join
  get_node_number
  get_node_index
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
  wait_until_resources_stopped
  wait_until_resources_started
  wait_for_idle_cluster
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
  script_output_retry_check
  calculate_sbd_start_delay
  setup_sbd_delay
  set_sbd_service_timeout
  collect_sbd_delay_parameters
  check_iscsi_failure
  cluster_status_matches_regex
);

=head1 SYNOPSIS

Library with common methods and default values for High Availability
Extension (HA or HAE) tests.

=cut

=head2 Global Variables

=over

=item * B<$default_timeout>: default scaled timeout for most operations with SUT

=item * B<$join_timeout>: default scaled timeout for C<ha-cluster-join> calls

=item * B<$softdog_timeout>: default scaled timeout for the B<softdog> watchdog

=item * B<$crm_mon_cmd>: crm_mon (crm monitoring) command

=back

=cut

our $crm_mon_cmd = 'crm_mon -R -r -n -N -1';
our $softdog_timeout = bmwqemu::scale_timeout(60);
our $prev_console;
our $join_timeout = bmwqemu::scale_timeout(60);
our $default_timeout = bmwqemu::scale_timeout(30);
our $corosync_token = q@corosync-cmapctl | awk -F " = " '/runtime.config.totem.token\s/ {print int($2/1000)}'@;
our $corosync_consensus = q@corosync-cmapctl | awk -F " = " '/runtime.config.totem.consensus\s/ {print int($2/1000)}'@;
our $sbd_watchdog_timeout = q@grep -oP '(?<=^SBD_WATCHDOG_TIMEOUT=)[[:digit:]]+' /etc/sysconfig/sbd@;
our $sbd_delay_start = q@grep -oP '(?<=^SBD_DELAY_START=)([[:digit:]]+|yes|no)+' /etc/sysconfig/sbd@;
our $pcmk_delay_max = q@crm resource param stonith-sbd show pcmk_delay_max| sed 's/[^0-9]*//g'@;

# Private functions
sub _just_the_ip {
    my $node_ip = shift;
    if ($node_ip =~ /(\d+\.\d+\.\d+\.\d+)/) {
        return $1;
    }
    return 0;
}

sub _test_var_defined {
    my $var = shift;

    die 'A command in ' . (caller(1))[3] . ' did not return a defined value!' unless defined $var;
}

# Public functions

=head2 exec_csync

 exec_csync();

Runs C<csync2 -vxF> in the SUT, to sync files from SUT to other nodes in the
cluster. Sometimes it is expected that the first call to C<csync2 -vxF> fails,
so this method will run the command twice.

=cut

sub exec_csync {
    # Sometimes we need to run csync2 twice to have all the files updated!
    assert_script_run 'csync2 -vxF ; sleep 2 ; csync2 -vxF';
}

=head2 add_file_in_csync

 add_file_in_csync( value => '/path/to/file', [ conf_file => '/path/to/csync2.cfg' ] );

Adds F</path/to/file> to a csync2 configuration file in SUT. Path to add must be passed
with the named argument B<value>, while csync2 configuration file can be passed on the
named argument B<conf_file> (defaults to F</etc/csync2/csync2.cfg>). Returns true on
success or croaks if command execution fails in SUT.

=cut

sub add_file_in_csync {
    my %args = @_;
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

=head2 get_cluster_name

 get_cluster_name();

Returns the cluster name, as defined in the B<CLUSTER_NAME> setting. Croaks if the
setting is not defined, as it is a mandatory setting for HA tests.

=cut

sub get_cluster_name {
    return get_required_var('CLUSTER_NAME');
}

=head2 get_hostname

 get_hostname();

Returns the hostname, as defined in the B<HOSTNAME> setting. Croaks if the setting
is not defined, as it is a mandatory setting for HA tests.

=cut

sub get_hostname {
    return get_required_var('HOSTNAME');
}

=head2 get_node_to_join

 get_node_to_join();

Returns the hostname of the node to join, as defined in the B<HA_CLUSTER_JOIN>
setting. Croaks if the setting is not defined, as this setting is mandatory for
all nodes that run C<ha-cluster-join>. As such, avoid scheduling tests that
call this method on nodes that would run C<ha-cluster-init> instead.

=cut

sub get_node_to_join {
    return get_required_var('HA_CLUSTER_JOIN');
}

=head2 get_ip

 get_ip( $node_hostname );

Returns the IP address of a node given its hostname, either by calling the
C<host> command in SUT (which in turns would do a DNS query on tests using
support server), or by searching for the host entry in SUT's F</etc/hosts>.
Returns 0 on failure.

=cut

sub get_ip {
    my $node_hostname = shift;
    my $node_ip;

    if (get_var('USE_SUPPORT_SERVER')) {
        $node_ip = script_output_retry("host -t A $node_hostname", retry => 3, delay => 5);
    }
    else {
        $node_ip = script_output("awk 'BEGIN {RET=1} /$node_hostname/ {print \$1; RET=0; exit} END {exit RET}' /etc/hosts");
    }

    return _just_the_ip($node_ip);
}

=head2 get_my_ip

 get_my_ip();

Returns the IP address of SUT or 0 if the address cannot be determined. Special case of C<get_ip()>.

=cut

sub get_my_ip {
    my $netdevice = get_var('SUT_NETDEVICE', 'eth0');
    my $node_ip = script_output "ip -4 addr show dev $netdevice | sed -rne '/inet/s/[[:blank:]]*inet ([0-9\\.]*).*/\\1/p'";
    return _just_the_ip($node_ip);
}

=head2 get_node_number

 get_node_number();

Returns the number of nodes configured in the cluster.

=cut

sub get_node_number {
    my $index = is_sle('15-sp2+') ? 2 : 1;
    return script_output "crm_mon -1 | awk '/ nodes configured/ { print \$$index }'";
}

=head2 get_node_index

 get_node_index();

Returns the index number of the SUT. This information is taken from the
node hostnames, so be sure to define proper hostnames in the tests settings,
for example B<alpha-node01>, B<alpha-node02>, etc.

=cut

sub get_node_index {
    my $node_index = get_hostname;

    $node_index =~ s/.*([0-9][0-9])$/$1/;

    return int($node_index);
}

=head2 is_node

 is_node( $node_number );

Checks whether SUT is the node identified by B<$node_number>. Returns true or false.
This information is matched against the node hostname, so be sure to define proper
hostnames in the tests settings, for example B<alpha-node01>, B<alpha-node02>, etc.

=cut

sub is_node {
    my $node_number = shift;
    my $hostname = get_hostname;

    # Node number must be coded with 2 digits
    $node_number = sprintf("%02d", $node_number);

    # Return true if HOSTNAME contains $node_number at his end
    return ($hostname =~ /$node_number$/);
}

=head2 add_to_known_hosts

 add_to_known_hosts( $host );

Adds B<$host> to the F<.ssh/known_hosts> file of the current user in SUT.
Croaks if any of the commands to do so fail.

=cut

sub add_to_known_hosts {
    my $host_to_add = shift;
    assert_script_run "mkdir -p ~/.ssh";
    assert_script_run "chmod 700 ~/.ssh";
    assert_script_run "ssh-keyscan -H $host_to_add >> ~/.ssh/known_hosts";
}

=head2 choose_node

 choose_node( $node_number );

Returns the hostname of the node identified by B<$node_number>. This information
relies on the node hostnames, so be sure to define proper hostnames in the tests
settings, for example B<alpha-node01>, B<alpha-node02>, etc.

=cut

sub choose_node {
    my $node_number = shift;
    my $tmp_hostname = get_hostname;

    # Node number must be coded with 2 digits
    $node_number = sprintf("%02d", $node_number);

    # Replace the digit of HOSTNAME to create the new hostname
    $tmp_hostname =~ s/(.*)[0-9][0-9]$/$1$node_number/;

    # And return it
    return $tmp_hostname;
}

=head2 save_state

 save_state();

Prints the cluster configuration and cluster status in SUT, and saves the
screenshot.

=cut

sub save_state {
    script_run 'yes | crm configure show', $default_timeout;
    assert_script_run "$crm_mon_cmd", $default_timeout;
    save_screenshot;
}

=head2 is_package_installed

 is_package_installed( $package );

Checks if B<$package> is installed in SUT. Returns true or false.

=cut

sub is_package_installed {
    my $package = shift;
    my $ret = script_run "rpm -q $package";

    _test_var_defined $ret;
    return ($ret == 0);
}

=head2 check_rsc

 check_rsc( $resource );

Checks if cluster resource B<$resource> is configured in the cluster. Returns
true or false. 

=cut

sub check_rsc {
    my $rsc = shift;
    my $ret = script_run "grep -q '\\<$rsc\\>' <($crm_mon_cmd 2>/dev/null)";

    _test_var_defined $ret;
    return ($ret == 0);
}

=head2 ensure_process_running

 ensure_process_running( $process );

Checks for up to B<$default_timeout> seconds whether process B<$process> is
running in SUT. Returns 0 if process is running or croaks on timeout.

=cut

sub ensure_process_running {
    my $process = shift;
    my $starttime = time;
    my $ret = undef;

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
    _test_var_defined $ret;
    return $ret;
}

=head2 ensure_resource_running

 ensure_resource_running( $resource, $regexp );

Checks for up to B<$default_timeout> seconds in the output of
C<crm resource status $resource> if a resource B<$resource> is configured in
the cluster; uses B<$regexp> to check. Returns 0 on success or croaks on timeout.

=cut

sub ensure_resource_running {
    my ($rsc, $regex) = @_;
    my $starttime = time;
    my $ret = undef;

    while ($ret = script_run("grep -E -q '$regex' <(crm resource status $rsc)", $default_timeout)) {
        my $timerun = time - $starttime;
        if ($timerun < $default_timeout) {
            sleep 5;
        }
        else {
            die "Resource '$rsc' did not start within $default_timeout seconds";
        }
    }

    # script_run need to be defined to ensure a correct exit code
    _test_var_defined $ret;
    return $ret;
}

=head2 ensure_dlm_running

 ensure_dlm_running();

Checks that the C<dlm> resource is running in the cluster, and that its
associated process (B<dlm_controld>) is running in SUT. Returns 0 if
process is running or croaks on error.

=cut

sub ensure_dlm_running {
    die 'dlm is not running' unless check_rsc "dlm";
    return ensure_process_running 'dlm_controld';
}

=head2 write_tag

 write_tag( $tag );

Create a cluster-specific file in F</tmp/> of the SUT with B<$tag> as its content.
Returns 0 on success or croaks on failure.

=cut

sub write_tag {
    my $tag = shift;
    my $rsc_tag = '/tmp/' . get_cluster_name . '.rsc';
    my $ret = script_run "echo $tag > $rsc_tag";

    _test_var_defined $ret;
    return ($ret == 0);
}

=head2 read_tag

 read_tag();

Read the content of the cluster-specific file created in F</tmp/> with
C<write_tag()>. Returns the content of the file or croaks on failure.

=cut

sub read_tag {
    my $rsc_tag = '/tmp/' . get_cluster_name . '.rsc';

    return script_output "cat $rsc_tag 2>/dev/null";
}

=head2 block_device_real_path

 block_device_real_path( $device );

Returns the real path of the block device specified by B<$device> as shown
by C<realpath -ePL>, or croak on failure.

=cut

sub block_device_real_path {
    my $lun = shift;

    return script_output "realpath -ePL $lun";
}

=head2 lvm_add_filter

 lvm_add_filter( $type, $filter );

Add filter B<$filter> of type B<$type> to F</etc/lvm/lvm.conf>.

=cut

sub lvm_add_filter {
    my ($type, $filter) = @_;
    my $lvm_conf = '/etc/lvm/lvm.conf';

    assert_script_run "sed -ie '/^[[:blank:]][[:blank:]]*filter/s;\\[[[:blank:]]*;\\[ \"$type|$filter|\", ;' $lvm_conf";
}

=head2 lvm_remove_filter

 lvm_remove_filter( $filter );

Remove filter B<$filter> from F</etc/lvm/lvm.conf>.

=cut

sub lvm_remove_filter {
    my $filter = shift;
    my $lvm_conf = '/etc/lvm/lvm.conf';

    assert_script_run "sed -ie '/^[[:blank:]][[:blank:]]*filter/s;$filter;;' $lvm_conf";
}

=head2 rsc_cleanup

 rsc_cleanup( $resource );

Execute a C<crm resource cleanup> on the resource identified by B<$resource>.

=cut

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

=head2 ha_export_logs

 ha_export_logs();

Upload HA-relevant logs from SUT. These include: crm configuration, cluster
bootstrap log, corosync configuration, B<crm report>, list of installed packages,
list of iSCSI devices, F</etc/mdadm.conf>, support config and B<y2logs>. If available,
logs from the B<HAWK> test, from B<CTS> and from B<HANA> are also included.

=cut

sub ha_export_logs {
    my $bootstrap_log = '/var/log/ha-cluster-bootstrap.log';
    my $corosync_conf = '/etc/corosync/corosync.conf';
    my $crm_log = '/var/log/crm_report';
    my $packages_list = '/tmp/packages.list';
    my $iscsi_devs = '/tmp/iscsi_devices.list';
    my $mdadm_conf = '/etc/mdadm.conf';
    my $clustername = get_cluster_name;
    my $report_opt = !is_sle('12-sp4+') ? '-f0' : '';
    my $cts_log = '/tmp/cts_cluster_exerciser.log';
    my @y2logs;

    select_console 'root-console';

    # Extract HA logs and upload them
    script_run "touch $corosync_conf";
    script_run "crm report $report_opt -E $bootstrap_log $crm_log", 300;
    upload_logs("$bootstrap_log", failok => 1);
    upload_logs("$crm_log.tar.bz2", failok => 1);

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
    script_run "supportconfig -g -B $clustername", 300;
    upload_logs("/var/log/scc_$clustername.tgz", failok => 1);

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

=head2 check_cluster_state

 check_cluster_state( [ proceed_on_failure => 1 ] );

Check state of the cluster. This will call B<$crm_mon_cmd> to check the current
status of the cluster, check for inactive resources and for S<partition with quorum>
in the output of B<$crm_mon_cmd>, check the reported number of nodes in the output
of C<crm node list> and B<$crm_mon_cmd> is the same and run C<crm_verify -LV>.

With the named argument B<proceed_on_failure> set to 1, the method will use
B<script_run()> and attempt to run all commands in SUT without checking for errors.
Without it, the method uses B<assert_script_run()> and will croak on failure.

=cut

sub check_cluster_state {
    my %args = @_;

    # We may want to check cluster state without stopping the test
    my $cmd = (defined $args{proceed_on_failure} && $args{proceed_on_failure} == 1) ? \&script_run : \&assert_script_run;

    $cmd->("$crm_mon_cmd");
    if (is_sle '12-sp3+') {
        # Add sleep as command 'crm_mon' outputs 'Inactive resources:' instead of 'no inactive resources' on 12-sp5
        sleep 5;
        $cmd->("$crm_mon_cmd | grep -i 'no inactive resources'");
    }
    $cmd->('crm_mon -1 | grep \'partition with quorum\'');
    # In older versions, node names in crm node list output are followed by ": normal". In newer ones by ": member"
    $cmd->(q/crm_mon -s | grep "$(crm node list | grep -E -c ': member|: normal') nodes online"/);
    # As some options may be deprecated, test shouldn't die on 'crm_verify'
    if (get_var('HDDVERSION')) {
        script_run 'crm_verify -LV';
    }
    else {
        $cmd->('crm_verify -LV');
    }
}

=head2 wait_until_resources_stopped

 wait_until_resources_stopped( [ timeout => $timeout, minchecks => $tries ] );

Wait for resources to be stopped. Runs B<$crm_mon_cmd> until there are no resources
in B<stopping> state or up to B<$timeout> seconds. Timeout must be specified by the
named argument B<timeout> (defaults to 120 seconds). This timeout is scaled by the
factor specified in the B<TIMEOUT_SCALE> setting.  The named argument B<minchecks>
(defaults to 3, can be disabled with 0) provides a minimum number of times to check
independently of the return status; this helps avoid race conditions where the method
checks before the HA stack starts to stop the resources. Croaks on timeout.

=cut

sub wait_until_resources_stopped {
    my %args = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $ret = undef;
    my $starttime = time;
    my $minchecks = $args{minchecks} // 3;

    do {
        $ret = script_run "! ($crm_mon_cmd | grep -Eioq ':[[:blank:]]*stopping')", $default_timeout;
        # script_run need to be defined to ensure a correct exit code
        _test_var_defined $ret;
        my $timerun = time - $starttime;
        --$minchecks if ($minchecks);
        if ($timerun < $timeout) {
            sleep 5;
        }
        else {
            die "Cluster/resources did not stop within $timeout seconds";
        }
    } while ($minchecks || $ret);
}

=head2 wait_until_resources_started

 wait_until_resources_started( [ timeout => $timeout ] );

Wait for resources to be started. Runs C<crm cluster wait_for_startup> in SUT as well
as other verifications on newer versions of SLES (12-SP3+), for up to B<$timeout> seconds
for each command. Timeout must be specified by the named argument B<timeout> (defaults
to 120 seconds). This timeout is scaled by the factor specified in the B<TIMEOUT_SCALE>
setting. Croaks on timeout.

=cut

# If changing this, remember to also change wait_until_resources_started in tests/publiccloud/sles4sap.pm
sub wait_until_resources_started {
    my %args = @_;
    my @cmds = ('crm cluster wait_for_startup');
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $ret = undef;

    # Some CRM options can only been added on recent versions
    push @cmds, "grep -iq 'no inactive resources' <($crm_mon_cmd)" if is_sle '12-sp3+';
    push @cmds, "! (grep -Eioq ':[[:blank:]]*failed|:[[:blank:]]*starting' <($crm_mon_cmd))";

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
        _test_var_defined $ret;
    }
}

=head2 wait_for_idle_cluster

 wait_for_idle_cluster( [ timeout => $timeout ] );

Use `cs_wait_for_idle` to wait until the cluster is idle before continuing the tests.
Supply a timeout with the named argument B<timeout> (defaults to 120 seconds). This
timeout is scaled by the factor specified in the B<TIMEOUT_SCALE> setting. Croaks on
timeout.

=cut

sub wait_for_idle_cluster {
    my %args = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $outoftime = time() + $timeout;    # Current time plus timeout == time at which timeout will be reached
    return if script_run 'rpm -q ClusterTools2';    # cs_wait_for_idle only present if ClusterTools2 is installed
    while (1) {
        my $out = script_output 'cs_wait_for_idle --sleep 5', $timeout;
        last if ($out =~ /Cluster state: S_IDLE/);
        sleep 5;
        die "Cluster was not idle for $timeout seconds" if (time() >= $outoftime);
    }
}

=head2 get_lun

 get_lun( [ use_once => $bool ] );

Returns a LUN from the LUN list file stored in the support server or in the support
NFS share in scenarios without support server. If the named argument B<use_once>
is passed and set to true (defaults to true), the returned LUN will be removed from
the file, so it will not be selected again. Croaks on failure.

=cut

# This function returns the first available LUN
sub get_lun {
    my %args = @_;
    my $hostname = get_hostname;
    my $cluster_name = get_cluster_name;
    my $lun_list_file = '/tmp/' . $cluster_name . '-lun.list';
    my $use_once = $args{use_once} // 1;
    my $supportdir = get_var('NFS_SUPPORT_DIR', '/mnt');

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

=head2 check_device_available

 check_device_available( $device, [ $timeout ] );

Checks for the presence of a device in the SUT for up to a defined timeout
(defaults to 20 seconds). Returns 0 on success, or croaks on failure.

=cut

sub check_device_available {
    my ($dev, $tout) = @_;
    my $ret;
    my $tries = bmwqemu::scale_timeout($tout ? int($tout / 2) : 10);

    die "Must provide a device for check_device_available" unless (defined $dev);

    while ($tries and $ret = script_run "ls -la $dev") {
        --$tries;
        sleep 2;
    }

    _test_var_defined $ret;
    die "Device $dev not found" unless ($tries > 0 or $ret == 0);
    return $ret;
}

=head2 set_lvm_config

 set_lvm_config( $lvm_config_file, [ use_lvmetad => $val1, locking_type => $val2, use_lvmlockd => $val3, ... ] );

Configures the LVM parameters/values pairs passed as a HASH into the LVM configuration
file specified by the first argument B<$lvm_config_file>. These LVM parameters are
usually B<use_lvmetad>, B<locking_type> and B<use_lvmlockd> but any other existing
parameter from the LVM configuration file is also valid. Parameters that do not exist
in the LVM configuration file in SUT will be ignored. Returns 0 on success or croaks
on failure.

=cut

sub set_lvm_config {
    my ($lvm_conf, %args) = @_;
    my $cmd;

    foreach my $param (keys %args) {
        $cmd = sprintf("sed -ie 's/^\\([[:blank:]]*%s[[:blank:]]*=\\).*/\\1 %s/' %s", $param, $args{$param}, $lvm_conf);
        assert_script_run $cmd;
    }

    script_run "grep -E '^[[:blank:]]*use_lvmetad|^[[:blank:]]*locking_type|^[[:blank:]]*use_lvmlockd' $lvm_conf";
}

=head2 add_lock_mgr

 add_lock_mgr( $lock_manager );

Configures a B<$lock_manager> resource in the cluster configuration on SUT.
B<$lock_mgr> usually is either B<clvmd> or B<lvmlockd>, but any other cluster
primitive could work as well.

=cut

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
        # here and this makes the ci tests fail.
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
    export_logs;
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

=head2 is_not_maintenance_update

 is_not_maintenance_update( $package );

Checks if the package specified in B<$package> is not targeted by a maintenance
update. Returns true if the package is not targeted, i.e., package name does not
appear in the B<BUILD> setting and the B<MAINTENANCE> setting is active, or false
in all other cases.

=cut

sub is_not_maintenance_update {
    my $package = shift;
    # Allow to skip an openQA module if package is not targeted by maintenance update
    if (get_var('MAINTENANCE') && get_var('BUILD') !~ /$package/) {
        record_info('Skipped - MU', "$package test not needed here");
        return 1;
    }
    return 0;
}

=head2 activate_ntp

 activate_ntp();

Enables NTP service in SUT.

=cut

sub activate_ntp {
    my $ntp_service = is_sle('15+') ? 'chronyd' : 'ntpd';
    systemctl "enable --now $ntp_service.service";
}

=head2 script_output_retry_check

  script_output_retry_check(cmd=>$cmd, regex_string=>$regex_sring, [retry=>$retry, sleep=>$sleep, ignore_failure=>$ignore_failure]);

Executes command via 'script_output' subroutine and makes a sanity check against a regular expression. Command output is returned
after success, otherwise the command is retried defined number of times. Test dies after last unsuccessfull retry.

C<$cmd> command being executed.
C<$regex_string> regular expression to check output against.
C<$retry> number of retries. Defaults to C<5>.
C<$sleep> sleep time between retries. Defaults to C<10s>.
C<$ignore_failure> do not kill the test upon failure.

  Example: script_output_retry_check(cmd=>'hostname', regex_string=>'^node01$', retry=>'100', sleep=>'60', ignore_failure=>'1');

=cut

sub script_output_retry_check {
    my %args = @_;
    my $cmd = $args{cmd} // die('No command specified.');
    my $regex = $args{regex_string} // die('Regex input missing');
    my $retry = $args{retry} // 5;
    my $sleep = $args{sleep} // 10;
    my $ignore_failure = $args{ignore_failure} // "0";
    my $result;

    # Get rid of args irrelevant to script_output
    foreach my $key (keys %args) {
        delete $args{$key} unless grep { $_ eq $key } qw(timeout wait type_command proceed_on_failure quiet);
    }

    foreach (1 .. $retry) {
        $result = script_output($cmd, %args);
        return $result if $result =~ /$regex/;
        sleep $sleep;
        record_info('CMD RETRY', "Retry $_/$retry.\nScript output did not match pattern '$regex'\nOutput: $result");
        next;
    }

    die('Pattern did not match') unless $ignore_failure;
    return undef;
}

=head2 collect_sbd_delay_parameters

  script_output_retry_check();

Collects parameters required from SUT and returns them in HASH format.

=cut

sub collect_sbd_delay_parameters {
    # all commands below ($corosync_token, $corosync_consensus...) are defined and exported at the beginning of the library
    my %params = (
        'corosync_token' =>
          script_output_retry_check(cmd => $corosync_token, regex_string => '^\d+$', sleep => '3', retry => '3'),
        'corosync_consensus' =>
          script_output_retry_check(cmd => $corosync_consensus, regex_string => '^\d+$', sleep => '3', retry => '3'),
        'sbd_watchdog_timeout' =>
          script_output_retry_check(cmd => $sbd_watchdog_timeout, regex_string => '^\d+$', sleep => '3', retry => '3'),
        'sbd_delay_start' =>
          script_output_retry_check(cmd => $sbd_delay_start, regex_string => '^\d+$|yes|no', sleep => '3', retry => '3'),
        # pcmk_delay_max is not always present for example in 3 node clusters or diskless SBD scenario
        'pcmk_delay_max' => get_var('USE_DISKLESS_SBD') ? 30 :
          script_output_retry_check(cmd => $pcmk_delay_max, regex_string => '^\d+$', sleep => '3', retry => '3', ignore_failure => 1) // 0
    );

    return (%params);
}

=head2 calculate_sbd_start_delay

  calculate_sbd_start_delay(\%sbd_parameters);

Calculates start time delay after node is fenced.
Prevents cluster failure if fenced node restarts too quickly.
Delay time is used either if specified in sbd config variable "SBD_DELAY_START"
or calculated:
"corosync token timeout + consensus timeout + pcmk_delay_max + msgwait"
Variables 'corosync_token' and 'corosync_consensus' are converted to seconds.
For diskless SBD pcmk_delay_max is set to static 30s.

%sbd_parameters = {
    'corosync_token' => <runtime.config.totem.token>,
    'corosync_consensus' => <runtime.config.totem.consensus>,
    'sbd_watchdog_timeout' => <SBD_WATCHDOG_TIMEOUT>,
    'sbd_delay_start' => <SBD_DELAY_START>,
    'pcmk_delay_max' => <pcmk_delay_max>
}

If C<%sbd_parameters> argument is omitted, then function will
try to obtain the values from the configuration files.

=cut

sub calculate_sbd_start_delay {
    my ($sbd_parameters) = @_;
    my %params = ref($sbd_parameters) eq 'HASH' ? %$sbd_parameters : collect_sbd_delay_parameters();

    my $default_wait = 35 * get_var('TIMEOUT_SCALE', 1);
    record_info('SBD Params', Dumper(\%params));

    # if delay is false return 0sec wait
    if (grep /^$params{'sbd_delay_start'}$/, qw(no 0)) {
        record_info('SBD start delay', 'SBD delay disabled either in /etc/sysconfig/sbd or by provided function arguments');
        return 0;
    }

    # if delay is only true, calculate according to default equation
    if (grep /^$params{'sbd_delay_start'}$/, qw(yes 1)) {
        for my $param_key (keys %params) {
            croak("Parameter '$param_key' returned non numeric value: $params{$param_key}\n
                This might indicate test issue or unexpected HA configuration value.")
              if !looks_like_number($params{$param_key}) and $param_key ne 'sbd_delay_start';
        }
        my $sbd_delay_start_time =
          $params{'corosync_token'} +
          $params{'corosync_consensus'} +
          $params{'pcmk_delay_max'} +
          $params{'sbd_watchdog_timeout'} * 2;    # msgwait = sbd_watchdog_timeout * 2

        record_info('SBD start delay', "SBD delay calculated: $sbd_delay_start_time");
        return ($sbd_delay_start_time);
    }

    # if sbd_delay_stat is specified by number explicitly
    if (looks_like_number($params{'sbd_delay_start'})) {
        record_info('SBD start delay', "Specified explicitly in config: $params{'sbd_delay_start'}");
        return $params{'sbd_delay_start'};
    }
    return $default_wait;
}

=head2 setup_sbd_delay
    setup_sbd_delay()

=cut

sub setup_sbd_delay() {
    my $delay = get_var('HA_SBD_START_DELAY', '');

    if ($delay eq '') {
        record_info('SBD delay', "Skipping, variable 'HA_SBD_START_DELAY' not defined");
    }
    else {
        $delay =~ s/(?<![ye])s//g;
        croak("<\$set_delay> value must be either 'yes', 'no' or an integer. Got value: $delay")
          unless looks_like_number($delay) or grep /^$delay$/, qw(yes no);
        file_content_replace('/etc/sysconfig/sbd', '^SBD_DELAY_START=.*', "SBD_DELAY_START=$delay");
        record_info('SBD delay', "SBD delay set to: $delay");
    }
    # Calculate currently set delay
    $delay = calculate_sbd_start_delay();

    # set SBD service timeout to be higher (+30s) that calculated/set delay
    my $sbd_service_timeout = set_sbd_service_timeout($delay + 30);
    record_info('sbd.service', "Service start timeout for sbd.service set to: $sbd_service_timeout");

    return ($delay);
}

=head2 set_sbd_service_timeout
    set_sbd_service_timeout($service_timeout)

=cut

sub set_sbd_service_timeout {
    my ($service_timeout) = @_;
    croak "Argument 'service_timeout' not defined" unless defined($service_timeout);
    croak "Argument 'service_timeout' is not a number" unless looks_like_number($service_timeout);
    my $service_override_dir = "/etc/systemd/system/sbd.service.d/";
    my $service_override_filename = "sbd_delay_start.conf";
    my $service_override_path = $service_override_dir . $service_override_filename;

    # CMD RC is converted to true/false
    my $file_exists = script_run(join(" ", "test", "-e", $service_override_path, ";echo", "\$?"), quiet => 1) ? 1 : 0;

    if ($file_exists) {
        file_content_replace($service_override_path, '^TimeoutSec=.*', "TimeoutSec=$service_timeout");
    }
    else {
        my @content = ('[Service]', "TimeoutSec=$service_timeout");
        assert_script_run(join(" ", "mkdir", "-p", $service_override_dir));
        assert_script_run(join(" ", "bash", "-c", "\"echo", "'$_'", ">>", $service_override_path, "\"")) foreach @content;
    }
    record_info("Systemd SBD", "Systemd unit timeout for 'sbd.service' set to '$service_timeout'");

    return ($service_timeout);
}

=head2 check_iscsi_failure

 check_iscsi_failure();

Workaround for bsc#1129385, checks system log for iSCSI connection failures, if
necessary restarts iscsi and pacemaker service

=cut

sub check_iscsi_failure {
    # check system logs for iscsi, pacemaker and corosync failures
    assert_script_run 'journalctl -b --no-pager -o short-precise > bsc1129385-check-journal.log';
    my $iscsi_fails = script_run 'grep -q "iscsid: .*cannot make a connection to" bsc1129385-check-journal.log';
    my $csync_fails = script_run 'grep -q "corosync.service: Failed" bsc1129385-check-journal.log';
    my $pcmk_fails = script_run 'grep -E -q "pacemaker.service.+failed" bsc1129385-check-journal.log';

    # restart and mark as softfailure if all failure conditions are match
    if (defined $iscsi_fails and $iscsi_fails == 0 and defined $csync_fails
        and $csync_fails == 0 and defined $pcmk_fails and $pcmk_fails == 0)
    {
        record_soft_failure "bsc#1129385";
        upload_logs 'bsc1129385-check-journal.log';
        $iscsi_fails = script_run 'grep -q LIO-ORG /proc/scsi/scsi';
        systemctl 'restart iscsi' if ($iscsi_fails);
        systemctl 'restart pacemaker';
    }
}

=head3 cluster_status_matches_regex

Check crm status output against a hardcode regular expression in order to check the cluster health 

=over 1

=item B<SHOW_CLUSTER_STATUS> - Output from 'crm status' command

=back
=cut

sub cluster_status_matches_regex {
    my ($show_cluster_status) = @_;
    croak 'No crm status output' if (!$show_cluster_status);
    my @resource_list = ();
    my $previous_line = '';

    for my $line (split("\n", $show_cluster_status)) {
        if ($line =~ /\s?(stopped|failed|pending|blocked|starting|promoting):?/i) {
            push @resource_list, $previous_line;
            push @resource_list, $line;
        }
        else {
            $previous_line = $line;
        }
    }
    if (scalar @resource_list == 0) {
        return 0;
    }
    else {
        record_info("Cluster errors: ", join("\n", @resource_list));
        return 1;
    }
}

1;
