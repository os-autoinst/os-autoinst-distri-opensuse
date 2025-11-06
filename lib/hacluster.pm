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
use version_utils qw(is_sle package_version_cmp);
use Scalar::Util qw(looks_like_number);
use utils;
use testapi;
use lockapi;
use isotovideo;
use maintenance_smelt qw(get_incident_packages);
use x11utils qw(ensure_unlocked_desktop);
use Utils::Logging qw(export_logs record_avc_selinux_alerts);
use network_utils qw(iface);
use Carp qw(croak);
use Data::Dumper;
use XML::Simple;
use serial_terminal qw(select_serial_terminal set_serial_prompt serial_term_prompt);

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
  get_cluster_info
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
  execute_crm_resource_refresh_and_check
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
  is_not_maintenance_update
  activate_ntp
  script_output_retry_check
  calculate_sbd_start_delay
  setup_sbd_delay
  set_sbd_service_timeout
  collect_sbd_delay_parameters
  check_iscsi_failure
  cluster_status_matches_regex
  crm_wait_for_maintenance
  crm_check_resource_location
  generate_lun_list
  show_cluster_parameter
  set_cluster_parameter
  prepare_console_for_fencing
  crm_get_failcount
  crm_wait_failcount
  crm_resources_by_class
  crm_resource_locate
  crm_resource_meta_show
  crm_resource_meta_set
  crm_list_options
  get_sbd_devices
  parse_sbd_metadata
  list_configured_sbd
  sbd_device_report
  get_fencing_type
  check_crm_nonroot
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

=item * B<$corosync_token>: command to filter the value of C<runtime.config.totem.token> from the output of C<corosync-cmapctl>

=item * B<$corosync_consensus>: command to filter the value of C<runtime.config.totem.consensus> from the output of C<corosync-cmapctl>

=item * B<$sbd_watchdog_timeout>: command to extract the value of C<SBD_WATCHDOG_TIMEOUT> from C</etc/sysconfig/sbd>

=item * B<$sbd_delay_start>: command to extract the value of C<SBD_DELAY_START> from C</etc/sysconfig/sbd>

=item * B<$pcmk_delay_max>: command to get the value of the C<pcmd_delay_max> parameter from the STONITH resource in the cluster configuration.

=back

=cut

our $crm_mon_cmd = 'crm_mon -R -r -n -1';
our $softdog_timeout = bmwqemu::scale_timeout(60);
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
        assert_script_run("[[ -w $conf_file ]]", 180);

        # Add the value in conf_file and sync on all nodes
        assert_script_run "grep -Fq $args{value} $conf_file || sed -i 's|^}\$|include $args{value};\\n}|' $conf_file";
        exec_csync;
    }

    return 1;
}

=head2 get_cluster_info

get_cluster_info();

Returns a hashref containing the info parsed from the CLUSTER_INFOS variable.
This does not reflect the current state of the cluster but the intended steady
state once the LUNs are configured and the nodes have joined.

=cut

sub get_cluster_info {
    my ($cluster_name, $num_nodes, $num_luns) = split(/:/, get_required_var('CLUSTER_INFOS'));
    return {cluster_name => $cluster_name, num_nodes => $num_nodes, num_luns => $num_luns};
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
    my $netdevice = get_var('SUT_NETDEVICE', iface());
    my $node_ip = script_output "ip -4 addr show dev $netdevice | sed -rne '/inet/s/[[:blank:]]*inet ([0-9\\.]*).*/\\1/p'";
    return _just_the_ip($node_ip);
}

=head2 get_node_number

 get_node_number();

Returns the number of nodes configured in the cluster.

=cut

sub get_node_number {
    my $out = script_output "crm_mon -1";
    my ($number) = $out =~ /(\d+) nodes configured/ or die "get_node_number: unexpected crm_mon output";
    return $number;
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
    my $ret = script_run('yes | crm configure show', $default_timeout);

    # In this pipeline, "crm configure show" exits cleanly with 0, but "yes" keeps writing after
    # the pipe is closed and dies with SIGPIPE (128+13=141). We could ingore 141 exit code.
    if ($ret != 0 && $ret != 141) {
        record_info('crm configure show', 'Failed to run "crm configure show"', result => 'fail');
    }
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

=head2 execute_crm_resource_refresh_and_check

 execute_crm_resource_refresh_and_check();

Execute C<crm resource refresh> for specified C<resource> on C<instance_hostname>
and check the C<crm_failcount> returns C<value=0>.
Check no B<failover> happens and state of cluster resources is healthy.

=cut

sub execute_crm_resource_refresh_and_check {
    my (%args) = @_;
    my $instance_type = $args{instance_type};
    my $instance_id = $args{instance_id};
    my $instance_hostname = $args{instance_hostname};
    my $instance_sid = get_required_var('SAP_SID');
    my $resource = "rsc_sap_${instance_sid}_$instance_type$instance_id";

    # Delete resource's recorded failures before refresh
    record_info("Delete failcount", "delete sapinstance recorded failures of $resource");
    assert_script_run("sudo crm_failcount --delete -r $resource -N $instance_hostname");
    # Refresh resource
    record_info("Refresh $instance_type", "refresh sapinstance $resource");
    assert_script_run("sudo crm resource refresh $resource");

    # Query the current value of the resource's fail count
    record_info("Query $instance_type", "Query fail count of sapinstance $resource");
    my $str = script_output("sudo crm_failcount --query -r $resource -N $instance_hostname");
    $str =~ /value=(\d+)/;
    die 'Test failed to crm_failcount is non-zero' if (int($1));
    # Check cluster
    record_info('Cluster check', 'Checking state of cluster resources is healthy');
    check_cluster_state();
    # Check failover
    record_info('NoFailover check', 'Checking no failover happens');
    crm_check_resource_location(resource => $resource, wait_for_target => $instance_hostname);
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

    my $crm_log_name = script_output("echo \"FILE=\|\$(ls $crm_log* | tail -1)\|\"");
    $crm_log_name =~ /FILE=\|([^\|]+)\|/;
    $crm_log_name = $1;
    upload_logs("$crm_log_name", failok => 1);

    record_info('crm configure show', 'Failed to run "crm configure show"', result => 'fail') if (script_run("crm configure show > /tmp/crm.txt"));
    upload_logs('/tmp/crm.txt');

    # Extract YaST logs and upload them
    upload_y2logs(failok => 1) if is_sle('<16');

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
    enter_cmd "supportconfig -g -B $clustername; echo DONE-\$?- > /dev/$serialdev";
    my $ret = wait_serial qr/DONE-\d+-/, timeout => 300;
    # Make it softfail for not blocking qem bot auto approvals on 12-SP5
    # Command 'supportconfig' hangs on 12-SP5, wait_serial times out and returns 'undef'
    if (!defined($ret) && is_sle("=12-SP5")) {
        record_soft_failure 'poo#151612';
        # Send 'ctrl-c' to kill 'supportconfig' as it hangs
        send_key('ctrl-c');
    }
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

Checks the state of the cluster. Calls B<$crm_mon_cmd> and inspects its output checking:

=over 3

=item The current state of the cluster.

=item Inactive resources.

=item S<partition with quorum>

=back

Checks that the reported number of nodes in the output of C<crm node list> and B<$crm_mon_cmd>
is the same by calling C<check_online_nodes>.

And runs C<crm_verify -LV>.

With the named argument B<proceed_on_failure> set to 1, the function will use
B<script_run()> and attempt to run all commands in SUT without checking for errors.
Without it, the method uses B<assert_script_run()> and will croak on failure.

=cut

sub check_cluster_state {
    my %args = @_;

    # We may want to check cluster state without stopping the test
    my $cmd_sub = (defined $args{proceed_on_failure} && $args{proceed_on_failure} == 1) ? \&script_run : \&assert_script_run;

    $cmd_sub->("$crm_mon_cmd", 180);
    if (is_sle '12-sp3+') {
        # Add sleep as command 'crm_mon' outputs 'Inactive resources:' instead of 'no inactive resources' on 12-sp5
        sleep 5;
        $cmd_sub->("$crm_mon_cmd | grep -i 'no inactive resources'");
    }
    $cmd_sub->('crm_mon -1 | grep \'partition with quorum\'');

    # If running with versions of crmsh older than 4.4.2, do not use check_online_nodes (see POD below)
    # Fall back to the older method of checking Online vs. Configured nodes
    my $out = script_output(q|rpm -q --qf 'crmshver=%{VERSION}\n' crmsh|);
    my ($ver) = $out =~ /crmshver=(\S+)/m or die "Couldn't parse crmsh version from: $out";
    my $cmp_result = package_version_cmp($ver, '4.4.2');
    if ($cmp_result < 0) {
        $cmd_sub->(q/crm_mon -s | grep "$(crm node list | grep -E -c ': member|: normal') nodes online"/);
    }
    else {
        check_online_nodes(%args);
    }

    # As some options may be deprecated, test shouldn't die on 'crm_verify'
    if (get_var('HDDVERSION')) {
        script_run 'crm_verify -LV';
    }
    else {
        $cmd_sub->('crm_verify -LV');
    }
}

=head2 check_online_nodes

 check_online_nodes( [ proceed_on_failure => 1 ] );

Checks that the reported number of nodes in the output of C<crm node list> and B<$crm_mon_cmd>
is the same.

With the named argument B<proceed_on_failure> set to 1, the function will only report
the number of nodes configured and online. Otherwise it will die when the number of
configured nodes is different than the number of online nodes, or if it fails to get
any of these numbers.

This function is not exported and it's used only by C<check_cluster_state>.

This function requires crmsh-4.4.2 or newer.

=cut

sub check_online_nodes {
    my %args = @_;
    # In older versions, node names in output from commands 'crm node list' or 'crm node show',
    # are followed by ": normal". In newer ones by ": member"
    my $configured_nodes = script_output q@echo "|$(crm node show | grep -E -c ': member|: normal')|"@;
    $configured_nodes =~ /\|(\d+)\|/;
    $configured_nodes = $1 // 0;
    record_info 'Configured nodes', "Configured nodes: $configured_nodes";
    die 'Cluster has 0 nodes' if ($configured_nodes == 0 && !$args{proceed_on_failure});

    # Get online nodes with: crm_mon --exclude=all --include=nodes -1
    # Output will look like:
    # Node List:
    #   * Online: [ node01 node02 ]
    my $online_nodes = script_output 'crm_mon --exclude=all --include=nodes --output-as=text -1', %args;
    foreach (split(/\n/, $online_nodes)) {
        next unless /Online: \[\s+([^\]]+)\]/;
        # Assign array to scalar will give us number of elements in the list
        $online_nodes = split(/\s+/, $1);
    }
    record_info 'Online nodes', "Online nodes: $online_nodes";

    die "Could not calculate online nodes. Got: [$online_nodes]" if (($online_nodes !~ /^\d+$/) && !$args{proceed_on_failure});
    die 'Not all configured nodes are online' if (($configured_nodes - $online_nodes) && !$args{proceed_on_failure});
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

    # Execute each command to validate that the cluster is running
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
                record_info('Cluster status', script_output("$crm_mon_cmd"));
                save_state();
                die "Cluster/resources did not start within $timeout seconds (cmd='$cmd')";
            }
        }

        # script_run need to be defined to ensure a correct exit code
        _test_var_defined $ret;
    }
}

=head2 wait_for_idle_cluster

 wait_for_idle_cluster( [ timeout => $timeout ] );

Use C<cs_wait_for_idle> to wait until the cluster is idle before continuing the tests.
Supply a timeout with the named argument B<timeout> (defaults to 120 seconds). This
timeout is scaled by the factor specified in the B<TIMEOUT_SCALE> setting. Dies on
timeout.

=cut

sub wait_for_idle_cluster {
    my %args = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $interval = 5;
    my $outoftime = time() + $timeout;    # Current time plus timeout == time at which timeout will be reached
    my $chk_cmd = 'cs_wait_for_idle --sleep 5';
    if (script_run 'rpm -q ClusterTools2') {
        # cs_wait_for_idle only present if ClusterTools2 is installed.
        # If not installed, check with crmadmin and wait longer between checks
        $chk_cmd = q@crmadmin -q -S $(crmadmin -Dq | sed 's/designated controller is: //i')@;
        $interval = 30;
    }
    while (1) {
        my $out = script_output $chk_cmd, $timeout, proceed_on_failure => 1;
        last if ($out =~ /S_IDLE/);
        sleep $interval;
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

 add_lock_mgr( $lock_manager, [ force => bool ] );

Configures a B<$lock_manager> resource in the cluster configuration on SUT.
B<$lock_mgr> usually is either B<clvmd> or B<lvmlockd>, but any other cluster
primitive could work as well.

Takes a second named argument B<force> which if set to true will add C<--force>
to the B<crmsh> command. Should be used with care. Defaults to false.

=cut

sub add_lock_mgr {
    my ($lock_mgr, %args) = @_;
    $args{force} //= 0;
    my $cmd = join(' ', 'crm', ($args{force} ? '--force' : ''), 'configure', 'edit');

    assert_script_run "EDITOR=\"sed -ie '\$ a primitive $lock_mgr ocf:heartbeat:$lock_mgr'\" $cmd";
    assert_script_run "EDITOR=\"sed -ie 's/^\\(group base-group.*\\)/\\1 $lock_mgr/'\" $cmd";

    # Wait to get clvmd/lvmlockd running on all nodes
    sleep 5;
}

=head2 is_not_maintenance_update

 is_not_maintenance_update( $package );

Checks if the package specified in B<$package> is not targeted by a maintenance
update. Returns true if the package is not targeted, i.e., B<MAINTENANCE> setting
is active and package name does not appear in the B<BUILD> setting nor is it
in the list of packages in the related B<INCIDENT_ID>. Returns false in all other
cases. Besides the package B<$package>, it also checks for B<kernel> in the B<BUILD>
setting and the list of packages, as the tests should always run with updates to the
kernel.

=cut

sub is_not_maintenance_update {
    my $package = shift;
    # Allow to skip an openQA module if package is not targeted by maintenance update
    if (get_var('MAINTENANCE') && get_var('INCIDENT_ID')) {
        # If package is listed in BUILD, no need to check for more
        return 0 if (get_var('BUILD') =~ /$package|kernel/);
        # Package name is not in BUILD setting, but it can still be targeted by the
        # incident, so let's query SMELT to confirm
        my @incident_packages = get_incident_packages(get_required_var('INCIDENT_ID'));
        return 0 if (grep(/$package|kernel/, @incident_packages));
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

Executes command via C<script_output> subroutine and makes a sanity check against a regular expression. Command output is returned
after success, otherwise the command is retried a defined number of times. Test dies after last unsuccessfull retry.

B<$cmd> command being executed.

B<$regex_string> regular expression to check output against.

B<$retry> number of retries. Defaults to C<5>.

B<$sleep> sleep time between retries. Defaults to C<10s>.

B<$ignore_failure> do not kill the test upon failure.

  Example: script_output_retry_check(cmd=>'hostname', regex_string=>'^node01$', retry=>'100', sleep=>'60', ignore_failure=>'1');

=cut

sub script_output_retry_check {
    my %args = @_;
    foreach (qw(cmd regex_string)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my $cmd = $args{cmd};
    my $regex = $args{regex_string};
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

  collect_sbd_delay_parameters();

Collects a series of SBD parameters from the SUT and returns them in a HASH format. Commands are
collected from C</etc/sysconfig/sbd> or by filtering the output of C<corosync-cmapctl>. Due to
possible race conditions, all these parameters are collected using the helper function
C<script_output_retry_check> also defined in this library.

=cut

sub collect_sbd_delay_parameters {
    # Depending on when this function is executed, the cmap API may not be ready
    # (for example, after a fence). Since corosync-cmapctl is used to get some
    # of the params below, lets first confirm cmap API is ready
    script_retry('corosync-cmapctl', delay => 30, timeout => $default_timeout, fail_message => 'cmap API not ready');

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
This delay time is used as a wait time after a node fence to prevent
cluster failures in cases where the fenced node restarts too quickly.
Delay time is used either if specified in sbd config variable B<SBD_DELAY_START>
or calculated by the formula:

corosync token timeout + consensus timeout + pcmk_delay_max + msgwait

Variables B<corosync_token> and B<corosync_consensus> are converted to seconds.
For diskless SBD pcmk_delay_max is set to static 30s.

  %sbd_parameters = {
      'corosync_token' => <runtime.config.totem.token>,
      'corosync_consensus' => <runtime.config.totem.consensus>,
      'sbd_watchdog_timeout' => <SBD_WATCHDOG_TIMEOUT>,
      'sbd_delay_start' => <SBD_DELAY_START>,
      'pcmk_delay_max' => <pcmk_delay_max>
  }

If C<%sbd_parameters> argument is omitted, then function will
try to obtain the values from the configuration files. See
C<collect_sbd_delay_parameters>

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

This function configures in the SUT the B<SBD_DELAY_START> parameter in
C</etc/sysconfig/sbd> to whatever value is supplied in the setting
B<HA_SBD_START_DELAY>, and then call C<calculate_sbd_start_delay> and
C<set_sbd_service_timeout> to set the service timeout for the SBD service
in the SUT. It returns the calculated delay. Will croak if any of the
commands sent to the SUT fail.

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

Set the service timeout for the SBD service in the SUT to the number of
seconds passed as argument.

This is accomplished by configuring a systemd override file for the
SBD service.

If the override file exists, the function will edit it and replace the
timeout there, otherwise it creates the file from scratch.

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

=head2 cluster_status_matches_regex

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

=head2 crm_maintenance_status

    crm_maintenance_status();

Check maintenance mode status. Returns true (maintenance active) or false (maintenance inactive).
Croaks if unknown status is received.

=cut

sub crm_maintenance_status {
    my $cmd_output = script_output('crm configure show cib-bootstrap-options | grep maintenance-mode');
    $cmd_output =~ s/\s//g;
    my $status = (split('=', $cmd_output))[-1];
    croak "CRM returned unrecognized status: '$status'" unless grep(/^$status$/, ('false', 'true'));
    return $status;
}

=head2 crm_wait_for_maintenance

    crm_wait_for_maintenance(target_state=>$target_state, [loop_sleep=>$loop_sleep, timeout=>$timeout]);

Wait for maintenance to be turned on or off. Croaks on timeout.

=over 3

B<target_state> Target state of the maintenance mode (true/false)

B<loop_sleep> Override default sleep value between checks

B<timeout> Override default timeout value

=back

=cut

sub crm_wait_for_maintenance {
    my (%args) = @_;
    my $timeout = $args{timeout} // bmwqemu::scale_timeout(30);
    my $loop_sleep = $args{loop_sleep} // 5;

    croak "Invalid argument value: \$target_state = '$args{'target_state'}'" unless grep(/^$args{'target_state'}$/, ('false', 'true'));

    my $current_status = crm_maintenance_status();
    my $start_time = time;
    while ($current_status ne $args{'target_state'}) {
        $current_status = crm_maintenance_status();
        croak "Timeout while waiting for maintenance mode: '$args{'target_state'}'" if (time - $start_time > $timeout);
        sleep $loop_sleep;
    }
    record_info("Maintenance", "Maintenance status: $current_status");
    return $current_status;
}

=head2 crm_check_resource_location

    crm_check_resource_location(resource=>$resource, [wait_for_target=>$wait_for_target, timeout=>$timeout]);

Checks current resource location, returns hostname of the node. Can be used to wait for desired state Eg: after failover.
Croaks upon timeout.

=over 3

B<wait_for_target> Target location of the resource specified - physical hostname

B<resource> Resource to check

B<timeout> Override default timeout value

=back

=cut

sub crm_check_resource_location {
    my (%args) = @_;
    croak 'Missing mandatory argument "$args{resource}"' unless $args{resource};
    my $wait_for_target = $args{wait_for_target} // 0;
    my $timeout = $args{timeout} // bmwqemu::scale_timeout(120);
    # Grep to avoid random kernel message appearing in script_output
    my $cmd = join(' ', "crm resource status", $args{resource}, "| grep 'resource $args{resource} is'");
    my $out;
    my $current_location;

    my $start_time = time();
    while (time() < ($start_time + $timeout)) {
        $out = script_output($cmd);
        $current_location = (split(': ', $out))[-1];
        return ($current_location) unless ($wait_for_target);
        return ($current_location) if $wait_for_target eq $current_location;
        sleep 5;
    }

    croak "Test timed out while waiting for resource '$args{resource}' to move to '$wait_for_target'";
}

=head2 generate_lun_list

    generate_lun_list()

This generates the information that nodes need to use iSCSI. This is stored in
/tmp/$cluster_name-lun.list where nodes can get it using scp.


=cut

sub generate_lun_list {
    my $target_iqn = script_output('lio_node --listtargetnames 2>/dev/null');
    my $target_ip_port = script_output("ls /sys/kernel/config/target/iscsi/${target_iqn}/tpgt_1/np 2>/dev/null");
    my $dev_by_path = '/dev/disk/by-path';
    my $index = get_var('ISCSI_LUN_INDEX', 0);

    my $cluster_infos = get_cluster_info();
    my $cluster_name = $cluster_infos->{cluster_name};
    my $num_luns = $cluster_infos->{num_luns};
    # Export LUN name if needed
    if (defined $num_luns) {
        # Create a file that contains the list of LUN for each cluster
        my $lun_list_file = "/tmp/$cluster_name-lun.list";
        foreach (0 .. ($num_luns - 1)) {
            my $lun_id = $_ + $index;
            script_run("echo '${dev_by_path}/ip-${target_ip_port}-iscsi-${target_iqn}-lun-${lun_id}' >> $lun_list_file");
        }
        $index += $num_luns;
    }
}


=head2 set_cluster_parameter

    set_cluster_parameter(resource=>'Totoro', parameter=>'neighbour', value=>'my');

Manage HA cluster parameter using crm shell.

=over

=item * B<resource>: Resource containing parameter

=item * B<parameter>: Parameter name

=item * B<value>: Target parameter value

=back

=cut

sub set_cluster_parameter {
    my (%args) = @_;
    foreach (qw(resource parameter value)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my $cmd = join(' ', 'crm', 'resource', 'param', $args{resource}, 'set', $args{parameter}, $args{value});
    assert_script_run($cmd);
}

=head2 show_cluster_parameter

    show_cluster_parameter(resource=>'Totoro', parameter=>'neighbour');

Show cluster parameter value using CRM shell.

=over

=item * B<resource>: Resource containing parameter

=item * B<parameter>: Parameter name

=back

=cut

sub show_cluster_parameter {
    my (%args) = @_;
    foreach (qw(resource parameter)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my $cmd = join(' ', 'crm', 'resource', 'param', $args{resource}, 'show', $args{parameter});
    return script_output($cmd);
}

=head2 prepare_console_for_fencing

    prepare_console_for_fencing();

Some HA tests modules will cause a node to fence. In these cases, the tests will need
to assert a B<grub2> or B<bootmenu> screen, so the modules will need to select the
C<root-console> before any calls to C<assert_screen>. On some systems, a simple call
to C<select_console 'root-console'> will not work as the console could be "dirty" with
messages obscuring the root prompt. This function will pre-select the console without
asserting anything on the screen, clear it, and then select it normally.

=cut

sub prepare_console_for_fencing {
    select_console 'root-console', await_console => 0;
    send_key 'ctrl-l';
    send_key 'ret';
    select_console 'root-console';
}

=head2 crm_get_failcount

    crm_get_failcount(crm_resource=>'ASCS_00' [, assert_result=>'true']);

Returns failcount number for specified resource.

=over

=item * B<crm_resource>: Cluster resource name

=item * B<assert_result>: Make test fail instead of returning value. Default: 'false'

=back

=cut

sub crm_get_failcount {
    my (%args) = @_;
    croak 'Missing mandatory argument "$args{crm_resource}"' unless $args{crm_resource};
    my $cmd = join(' ', 'crm_failcount', '--query', "--resource=$args{crm_resource}");
    my %result = map { my ($key, $value) = split(/=/, $_); $key => $value } split(/ +/, script_output($cmd));
    die "Cluster resource '$args{crm_resource}' has positive fail count value: '$result{value}'"
      if $result{value} != '0' && $args{assert_result};

    return $result{value};
}

=head2 crm_wait_failcount

    crm_wait_failcount(crm_resource=>'ASCS_00' [, timeout=>'60', delay=>'3']);

Waits till crm fail count reached non-zero value of fail after B<timeout>

=over

=item * B<crm_resource>: Cluster resource name

=item * B<timeout>: Give up after timeout in sec. Default 60 sec.

=item * B<delay>: Delay between retries. Default: 5 sec

=back

=cut

sub crm_wait_failcount {
    my (%args) = @_;
    croak 'Missing mandatory argument "$args{crm_resource}"' unless $args{crm_resource};
    $args{timeout} //= 300;
    $args{delay} //= 5;


    my $result = 0;
    my $start_time = time;
    while ($result == 0) {
        $result = crm_get_failcount(crm_resource => $args{crm_resource});
        sleep $args{delay};
        last if (time() > ($start_time + $args{timeout}));
    }

    die "Fail count is still 0 after timeout: '$args{timeout}'" if $result == 0;
    return ($result);
}


=head2 crm_resources_by_class

    crm_resources_by_class(primitive_class=>'stonith:external/sbd');

Returns resource name ARRAYREF filtered by class.
Refer to CRM help pages for details: C<crm configure show --help> and C<crm ra classes>

=over

=item * B<primitive_class>: CRM resource class name. Example: 'stonith:external/sbd', 'IPaddr2'

=back

=cut

sub crm_resources_by_class {
    my (%args) = @_;
    croak 'Missing mandatory argument: "$args{primitive_class}"' unless $args{primitive_class};
    my @result;
    # Filter only 'primitive' line
    foreach (split("\n", script_output("crm configure show related:$args{primitive_class} | grep primitive"))) {
        # split primitive line "primitive <name> <class>"
        my @aux = split(/\s+/, $_);
        if ($aux[2]) {
            # additional check if returned resource exists for some bogus value
            assert_script_run("crm resource status $aux[1]");
            push @result, $aux[1];
        }
    }
    return \@result;
}

=head2 crm_resource_locate

    crm_resource_locate(crm_resource=>'ASCS_00');

Returns hostname of cluster node where defined B<crm_resource> currently resides.

=over

=item * B<crm_resource>: Cluster resource name

=back

=cut

sub crm_resource_locate {
    my (%args) = @_;
    croak 'Missing mandatory argument: "$args{crm_resource}"' unless $args{crm_resource};
    # Command outputs something like: 'resource rsc_sap_QES_ASCS01 is running on: qesscs01lc14'
    my $result = script_output("crm resource locate $args{crm_resource}");
    return (split(':\s', $result))[1];
}

=head2 crm_resource_meta_show

    crm_resource_meta_show(resource=>'Totoro', meta_argument=>'neighbour');

Return resource meta-argument value.

=over

=item * B<resource>: Resource containing parameter

=item * B<meta_argument>: Meta-argument name

=back

=cut

sub crm_resource_meta_show {
    my (%args) = @_;
    foreach (qw(resource meta_argument)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    return script_output("crm resource meta $args{resource} show $args{meta_argument}");
}

=head2 crm_resource_meta_set

    crm_resource_meta_set(resource=>'Totoro', meta_argument=>'neighbour', argument_value=>'my');

Change or delete resource meta-argument value.

=over

=item * B<resource>: Resource containing parameter

=item * B<meta_argument>: Meta-argument name

=item * B<argument_value>: Meta-argument value. If B<undef>, meta argument will be removed.

=back

=cut

sub crm_resource_meta_set {
    my (%args) = @_;

    foreach (qw(resource meta_argument)) { croak "Missing mandatory $_ argument" unless $args{$_}; }
    my $action = $args{argument_value} ? 'set' : 'delete';
    my $cmd = "crm resource meta $args{resource} $action $args{meta_argument}";
    $cmd .= " $args{argument_value}" if $action eq 'set';

    assert_script_run($cmd);
    record_info('CRM meta set', "CRM meta set: $cmd");
}

=head2 crm_list_options

    my $ret = crm_list_options();

Executes a series of C<crm> commands to list metadata options for different
resource types (primitive, fencing, cluster attributes) and validates that their
XML output is well-formed. This function is designed to test a new feature in
C<crmsh> version 5.0.0 and newer, which provides a CLI interface to query
resource meta-attributes.

The function will execute the following commands:

=over

=item * C<crm_resource --list-options primitive --output-as xml>

=item * C<crm_resource --list-options fencing --output-as xml>

=item * C<crm_attribute --list-options cluster --all --output-as=xml>

=back

B<Return values:>

=over

=item * B<1>: All commands executed successfully and their XML output was valid.

=item * B<0>: The installed C<crmsh> version is older than 5.0.0. The function performs no operation.

=item * B<-1>: At least one of the commands produced output that was not valid XML.

=back

=cut

sub crm_list_options {
    my (%args) = @_;

    my $outver = script_output(q|rpm -q --qf 'crmshver=%{VERSION}\n' crmsh|);
    my ($ver) = $outver =~ /crmshver=(\S+)/m or die "Couldn't parse crmsh version from: $outver";
    my $cmp_result = package_version_cmp($ver, '5.0.0');
    return 0 if ($cmp_result < 0);
    my $out;

    my $parser = XML::Simple->new;
    my $ret = 1;
    foreach (
        'crm_resource  --list-options primitive     --output-as xml',
        'crm_resource  --list-options fencing       --output-as xml',
        'crm_attribute --list-options cluster --all --output-as=xml') {
        $out = script_output($_);
        eval { $parser->parse_string($out) };
        if ($@) {
            $ret = -1;
            diag("XML parsing error for '$_' output:\n $@");
        }
    }
    return $ret;
}

=head2 get_sbd_devices

    my @ret = get_sbd_devices($hostname);

Executes 'crm sbd status' to get sbd configuration, and return the devices information
for the specify node.

Following is the result of `crm sbd status`, we will check if there are two device on each node.
status of sdb.service:

Node                          |Active      |Enable         |Since
2nodes-node01:       |YES          |YES              | active since: Tue 2025-07-22 09:45:21
2nodes-node02:       |YES          |YES              | active since: Tue 2025-07-22 09:45:21

# Status of the sbd disk watcher process on 2nodes-node01:
|-3059 sbd: watcher: /dev/disk/by-path/xxxxxxx - slot : 0 --uuid xxxx
|-3060 sbd: watcher: /dev/disk/by-path/xxxxxxx - slot : 0 --uuid xxxx

# Status of the sbd disk watcher process on 2nodes-node02:
|-3058 sbd: watcher: /dev/disk/by-path/xxxxxxx - slot : 0 --uuid xxxx
|-3061 sbd: watcher: /dev/disk/by-path/xxxxxxx - slot : 0 --uuid xxxx

# Watchdog info:
Node.                    |Device                    |Driver           |Kernel Timeout
2nodes-node01  |/dev/watchdog.   | <unknown>    | 10
2nodes-node02  |/dev/watchdog.   | <unknown>    | 10

=over

=item B<Parameters:>

=over

=item C<$hostname>

String. The name of the node to query.

=back

=item B<Return values:>

Array. List of SBD devices, e.g. (sbd_device1, sbd_device2)

=back

=cut

sub get_sbd_devices {
    my $hostname = shift;

    my $in_block = 0;
    my @devices;
    foreach my $line (split /\n/, script_output('crm sbd status')) {
        if ($line =~ /^# Status of the sbd disk watcher process on \Q$hostname\E:/) {
            $in_block = 1;
            next;
        }

        if ($line =~ /^# Status of the sbd disk watcher process on / or $line =~ /^# Watchdog info:/) {
            $in_block = 0;
        }

        if ($in_block && $line =~ /watcher:\s+(\S+)/) {
            push @devices, $1;
        }
    }
    return @devices;
}

=head2 parse_sbd_metadata

    my @ret = parse_sbd_metadata;

Executes 'crm sbd configure show disk_metadata' to get sbd information, and return the devices and metadata value.

Following is the result of `crm sbd configure show disk_metadata`, we will check if there are two device on each node.
INFO: crm sbd configure show disk_metadata
==Dumping header on disk /dev/disk/by-path/xxxxx
Header version      : 2.1
UUID                : xxx
Number of slots     : 255
Sector size         : 512
Timeout (watchdog)  : 5
Timeout (allocate)  : 10
Timeout (loop)      : 2
Timeout (msgwait)   : 5
==Header on disk /dev/disk/by-path/xxxxxxx is dumped

# If there is a second sbd device
==Dumping header on disk /dev/disk/by-path/xxxxx
Header version      : 2.1
UUID                : xxx
Number of slots     : 255
Sector size         : 512
Timeout (watchdog)  : 5
Timeout (allocate)  : 10
Timeout (loop)      : 2
Timeout (msgwait)   : 5
==Header on disk /dev/disk/by-path/xxxxxxx is dumped

=over

=item B<Return values:>

   (
          {
            'metadata' => {
                            'allocate' => '10',
                            'loop' => '2',
                            'msgwait' => '5',
                            'watchdog' => '5'
                          },
            'device_name' => '/dev/disk/by-path/xxxxx'
          },
          {
            'device_name' => '/dev/disk/by-path/xxxxx',
            'metadata' => {
                            'allocate' => '10',
                            'loop' => '2',
                            'msgwait' => '5',
                            'watchdog' => '5'
                          }
          }
        ])

=back

=cut

sub parse_sbd_metadata {
    my @val = ();
    my $metadata = {};
    my $device_name = "";
    foreach my $line (split(/\n/, script_output('crm sbd configure show disk_metadata'))) {
        if ($line =~ /^==Dumping header on disk (\S+)/) {
            $device_name = $1;
        } elsif ($line =~ /Timeout\s+\((\w+)\)\s+\:\s+(\d+)/) {
            $metadata->{$1} = $2;
        } elsif ($line =~ /^==Header on disk (\S+) is dumped$/) {
            push @val, {device_name => $device_name, metadata => $metadata};

            # Init the device_name and metadata hash;
            $device_name = "";
            $metadata = {};
        }
    }
    return @val;
}

=head2 list_configured_sbd

    list_configured_sbd();

Returns list of SBD devices defined in `/etc/sysconfig/sbd` as an B<ARRAYREF>. Example: ['/device/1', '/device/2']

=cut

sub list_configured_sbd {
    my (%args) = @_;
    # return if file does not exist - means no SBD setup
    return [] if script_run('test -f /etc/sysconfig/sbd');
    my $sbd_devices = script_output('grep -E ^SBD_DEVICE /etc/sysconfig/sbd', proceed_on_failure => '1');
    return [] unless $sbd_devices;
    $sbd_devices =~ s/SBD_DEVICE=|"//g;
    my @sbd_devices = split(';', $sbd_devices);
    assert_script_run("test -b $_", fail_message => "SBD device '$_' not found") foreach @sbd_devices;
    return \@sbd_devices;
}

=head2 sbd_device_report

    sbd_device_report(device_list=>['/device/one', '/device/two']);

Executes various SBD related commands and returns report compiled from the outputs as a single string.

=over

=item * B<device_list> List of devices as an B<ARRAYREF> that should be included in the report.

=item * B<expected_sbd_devices_count> Optional check if number of expected SBD devices deployed matches current state.

=back

=cut

sub sbd_device_report {
    my (%args) = @_;
    my $separator = "\n" . '*' x 50 . "\n";
    my $report = "SBD Device report$separator";
    # Optional check if number of expected SBD devices matches current state
    if ($args{expected_sbd_devices_count}) {
        my $number_of_sbds = $args{device_list} ? @{$args{device_list}} : '0';
        $report .= "Check SBD device count :\n";
        $report .= ($args{expected_sbd_devices_count} == $number_of_sbds) ?
          "PASS: Number of expected ($args{expected_sbd_devices_count}) devices matched${separator}" :
          "FAIL: Number of expected ($args{expected_sbd_devices_count}) devices does not match current state ($number_of_sbds)${separator}";
    }

    # no need to run commands if there are no SBD devices configured
    return $report unless $args{device_list};
    $report .= join("\n", 'Device list:', @{$args{device_list}});
    $report .=
      join("\n", map { "${separator}Slot $_:\n" . script_output("sbd list -d $_") } @{$args{device_list}});
    $report .=
      join("\n", map { "${separator}Dump $_:\n" . script_output("sbd dump -d $_") } @{$args{device_list}});

    return $report;
}

=head2 get_fencing_type

    get_fencing_type();

Checks which stonith resource type is configured using B<crm shell>.
Returns full type name ('external/sbd', 'fence_azure_arm', ...).

=cut

sub get_fencing_type {
    my $stonith_type = script_output('crm configure show type:primitive | grep stonith');
    $stonith_type =~ m/stonith:(.*)\s/;
    return $1;
}

=head2 check_crm_nonroot

    check_crm_nonroot();

Checks if non-root user run 'crm configure show' successfully

=over

=item * B<user> non-root user, usually be <sid>adm

=back

=cut

sub check_crm_nonroot {
    my $user = shift // die 'check_crm_nonroot requires a username';

    # Get the command 'crm' path
    my $command = script_output('which crm');

    # Set the user into haclient job group because of `crm` permission
    assert_script_run("usermod -a -G haclient $user");

    my $orig_prompt = serial_term_prompt() // '# ';

    # Login as non-root user
    enter_cmd "su - $user";
    wait_serial '> ', no_regex => 1, timeout => 2;
    set_serial_prompt '> ';

    # Unset all related PATH which belong to non-root user.
    my @paths = ('PYTHONPATH', 'PYTHONHOME', 'PYTHON_DIR', 'PYTHON_MODULES_DIR', 'PYTHON_VERSION', 'PYTHON_VERSION_FILE', 'LD_LIBRARY_PATH');
    foreach my $path (@paths) {
        assert_script_run("unset $path");
    }

    # Run crm configure show
    assert_script_run("yes | $command configure show");

    # Exit non-root user
    enter_cmd 'exit';

    $testapi::distri->{serial_term_prompt} = $orig_prompt;
    wait_serial $orig_prompt, no_regex => 1, timeout => 2;

    select_serial_terminal();
}

1;
