# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Library used for SLES4SAP publicccloud deployment and tests
#
# Note: Subroutines executing commands on remote host (using "run_cmd" or "run_ssh_command") require
# to have $self->{my_instance} defined.
# $self->{my_instance} defines what is the target instance to execute code on. It is acquired from
# data located in "@instances" and produced by deployment test modules.

package sles4sap_publiccloud;

use base 'publiccloud::basetest';
use strict;
use warnings FATAL => 'all';
use Exporter 'import';
use Scalar::Util 'looks_like_number';
use publiccloud::utils;
use publiccloud::provider;
use publiccloud::ssh_interactive 'select_host_console';
use testapi;
use List::MoreUtils qw(uniq);
use utils 'file_content_replace';
use Carp qw(croak);
use hacluster;
use qesapdeployment;
use YAML::PP;
use publiccloud::instance;
use sles4sap;

our @EXPORT = qw(
  run_cmd
  get_promoted_hostname
  is_hana_resource_running
  stop_hana
  start_hana
  check_takeover
  get_replication_info
  is_hana_online
  get_hana_topology
  enable_replication
  cleanup_resource
  get_promoted_instance
  wait_for_sync
  wait_for_pacemaker
  cloud_file_content_replace
  change_sbd_service_timeout
  setup_sbd_delay_publiccloud
  sbd_delay_formula
  create_instance_data
  deployment_name
  delete_network_peering
  create_playbook_section_list
  create_hana_vars_section
  azure_fencing_agents_playbook_args
  display_full_status
  list_cluster_nodes
  sles4sap_cleanup
  is_hana_database_online
  get_hana_database_status
  is_primary_node_online
);

=head2 run_cmd
    run_cmd(cmd => 'command', [runas => 'user', timeout => 60]);

    Runs a command C<cmd> via ssh in the given VM and log the output.
    All commands are executed through C<sudo>.
    If 'runas' defined, command will be executed as specified user,
    otherwise it will be executed as root.
=cut

sub run_cmd {
    my ($self, %args) = @_;
    croak("Argument <cmd> missing") unless ($args{cmd});
    croak("\$self->{my_instance} is not defined. Check module Description for details") unless $self->{my_instance};
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);
    my $title = $args{title} // $args{cmd};
    $title =~ s/[[:blank:]].+// unless defined $args{title};
    my $cmd = defined($args{runas}) ? "su - $args{runas} -c '$args{cmd}'" : "$args{cmd}";

    # Without cleaning up variables SSH commands get executed under wrong user
    delete($args{cmd});
    delete($args{title});
    delete($args{timeout});
    delete($args{runas});

    my $out = $self->{my_instance}->run_ssh_command(cmd => "sudo $cmd", timeout => $timeout, %args);
    record_info("$title output - $self->{my_instance}->{instance_id}", $out) unless ($timeout == 0 or $args{quiet} or $args{rc_only});
    return $out;
}

=head2 get_promoted_hostname()
    get_promoted_hostname();

    Checks and returns hostname of HANA promoted node according to crm shell output.
=cut

sub get_promoted_hostname {
    my ($self) = @_;
    my $hana_resource = join("_",
        "msl",
        "SAPHana",
        "HDB",
        get_required_var("INSTANCE_SID") . get_required_var("INSTANCE_ID"));

    my $resource_output = $self->run_cmd(cmd => "crm resource status " . $hana_resource, quiet => 1);
    record_info("crm out", $resource_output);
    my @master = $resource_output =~ /:\s(\S+)\sMaster/g;
    if (scalar @master != 1) {
        diag("Master database not found or command returned abnormal output.\n
        Check 'crm resource status' command output below:\n");
        diag($resource_output);
        die("Master database was not found, check autoinst.log");
    }

    return join("", @master);
}

=head2 sles4sap_cleanup

    Clean up Network peering and qesap deployment

=cut

sub sles4sap_cleanup {
    my ($self, %args) = @_;

    # If there's an open ssh connection to the VMs, return to host console first
    select_host_console(force => 1);
    record_info(
        'Cleanup',
        join(' ',
            'cleanup_called:',
            $args{cleanup_called} // 'undefined',
            'network_peering_present:',
            $args{network_peering_present} // 'undefined',
            'ansible_present:',
            $args{ansible_present} // 'undefined')
    );

    qesap_upload_logs();
    if ($args{network_peering_present}) {
        delete_network_peering();
    }

    # Do not run destroy if already executed
    return 0 if ($args{cleanup_called});
    my @cmd_list;

    # Only run the Ansible deregister if Ansible has been executed
    push(@cmd_list, 'ansible') if ($args{ansible_present});

    # Terraform destroy can be executed in any case
    push(@cmd_list, 'terraform');
    for my $command (@cmd_list) {
        record_info('Cleanup', "Executing $command cleanup");

        # 3 attempts for both terraform and ansible cleanup
        for (1 .. 3) {
            my @cleanup_cmd_rc = qesap_execute(
                verbose => '--verbose',
                cmd => $command,
                cmd_options => '-d',
                timeout => 1200
            );
            if ($cleanup_cmd_rc[0] == 0) {
                diag(ucfirst($command) . " cleanup attempt # $_ PASSED.");
                record_info("Clean $command",
                    ucfirst($command) . ' cleanup PASSED.');
                last;
            }
            else {
                diag(ucfirst($command) . " cleanup attempt # $_ FAILED.");
                sleep 10;
            }
            record_info(
                'Cleanup FAILED',
                "Cleanup $command FAILED",
                result => 'fail'
            ) if $_ == 3 && $cleanup_cmd_rc[0];
            return 0 if $_ == 3 && $cleanup_cmd_rc[0];
        }
    }
    record_info('Cleanup finished');
    return 1;

}

=head2 get_hana_topology
    get_hana_topology([hostname => $hostname]);

    Parses command output, returns list of hashes containing values for each host.
    If hostname defined, returns hash with values only for host specified.
=cut

sub get_hana_topology {
    my ($self, %args) = @_;
    my @topology;
    my $hostname = $args{hostname};
    my $cmd_out = $self->run_cmd(cmd => "SAPHanaSR-showAttr --format=script", quiet => 1);
    record_info("cmd_out", $cmd_out);
    my @all_parameters = map { if (/^Hosts/) { s,Hosts/,,; s,",,g; $_ } else { () } } split("\n", $cmd_out);
    my @all_hosts = uniq map { (split("/", $_))[0] } @all_parameters;

    for my $host (@all_hosts) {
        my %host_parameters = map { my ($node, $parameter, $value) = split(/[\/=]/, $_);
            if ($host eq $node) { ($parameter, $value) } else { () } } @all_parameters;
        push(@topology, \%host_parameters);

        if (defined($hostname) && $hostname eq $host) {
            return \%host_parameters;
        }
    }

    return \@topology;
}

=head2 is_hana_online
    is_hana_online([timeout => 120, wait_for_start => 'false']);

    Check if hana DB is online. Define 'wait_for_start' to wait for DB to start.
=cut

sub is_hana_online {
    my ($self, %args) = @_;
    my $wait_for_start = $args{wait_for_start} // 0;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $start_time = time;
    my $consecutive_passes = 0;
    my $db_status;

    while ($consecutive_passes < 3) {
        $db_status = $self->get_replication_info()->{online} eq "true" ? 1 : 0;
        return $db_status unless $wait_for_start;

        # Reset pass counter in case of fail.
        $consecutive_passes = $db_status ? ++$consecutive_passes : 0;
        die("DB did not start within defined timeout: $timeout s") if (time - $start_time > $timeout);
        sleep 10;
    }
    return $db_status;
}

=head2 is_hana_resource_running
    is_hana_resource_running([timeout => 60]);

    Checks if resource msl_SAPHana_* is running on given node.
=cut

sub is_hana_resource_running {
    my ($self) = @_;
    my $hostname = $self->{my_instance}->{instance_id};
    my $hana_resource = join("_",
        "msl",
        "SAPHana",
        "HDB",
        get_required_var("INSTANCE_SID") . get_required_var("INSTANCE_ID"));

    my $resource_output = $self->run_cmd(cmd => "crm resource status " . $hana_resource, quiet => 1);
    my $node_status = grep /is running on: $hostname/, $resource_output;
    record_info("Node status", "$hostname: $node_status");
    return $node_status;
}

=head2 stop_hana
    stop_hana([timeout => $timeout, method => $method]);

    Stops HANA database using default or specified method.
    "stop" - stops database using "HDB stop" command.
    "kill" - kills database processes using "HDB -kill" command.
    "crash" - crashes entire os using "/proc-sysrq-trigger" method.
=cut

sub stop_hana {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    my $method = $args{method} // 'stop';
    my %commands = (
        stop => "HDB stop",
        kill => "HDB kill -x",
        crash => "echo b > /proc/sysrq-trigger &"
    );

    croak("HANA stop method '$args{method}' unknown.") unless $commands{$method};
    my $cmd = $commands{$method};

    # Wait for data sync before stopping DB
    $self->wait_for_sync();

    record_info("Stopping HANA", "CMD:$cmd");
    if ($method eq "crash") {
        # Crash needs to be executed as root and wait for host reboot
        $self->{my_instance}->run_ssh_command(cmd => "sudo su -c sync", timeout => "0", %args);
        $self->{my_instance}->run_ssh_command(cmd => 'sudo su -c "' . $cmd . '"',
            timeout => "0",
            # Try only extending ssh_opts
            ssh_opts => "-o ServerAliveInterval=2 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR",
            %args);
        sleep 10;
        $self->{my_instance}->wait_for_ssh();
        return ();
    }
    else {
        my $sapadmin = lc(get_required_var('INSTANCE_SID')) . 'adm';
        $self->run_cmd(cmd => $cmd, runas => $sapadmin, timeout => $timeout);
    }
}

=head2 start_hana
    start_hana([timeout => 60]);

    Start HANA DB using "HDB start" command
=cut

sub start_hana {
    my ($self) = @_;
    $self->run_cmd(cmd => "HDB start", runas => get_required_var("SAP_SIDADM"));
}

=head2 cleanup_resource
    cleanup_resource([timeout => 60]);

    Cleanup resource 'msl_SAPHana_*', wait for DB start automatically.
=cut

sub cleanup_resource {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);

    $self->run_cmd(cmd => "crm resource cleanup");

    # Wait for resource to start
    my $start_time = time;
    while ($self->is_hana_resource_running() == 0) {
        if (time - $start_time > $timeout) {
            record_info("Cluster status", $self->run_cmd(cmd => $crm_mon_cmd));
            die("Resource did not start within defined timeout. ($timeout sec).");
        }
        sleep 30;
    }
}

=head2 check_takeover
    check_takeover();

    Checks takeover status and waits for finish until successful or reaches timeout.
=cut

sub check_takeover {
    my ($self) = @_;
    my $hostname = $self->{my_instance}->{instance_id};
    my $retry_count = 0;
    die("Database on the fenced node '$hostname' is not offline") if ($self->is_hana_database_online);
    die("System replication '$hostname' is not offline") if ($self->is_primary_node_online);

  TAKEOVER_LOOP: while (1) {
        my $topology = $self->get_hana_topology();
        $retry_count++;
        for my $entry (@$topology) {
            my %host_entry = %$entry;
            my $sync_state = $host_entry{sync_state};
            my $takeover_host = $host_entry{vhost};

            if ($takeover_host ne $hostname && $sync_state eq "PRIM") {
                record_info("Takeover status:", "Takeover complete to node '$takeover_host'");
                last TAKEOVER_LOOP;
            }
            sleep 30;
        }
        die "Test failed: takeover failed to complete." if ($retry_count > 40);
    }

    return 1;
}

=head2 enable_replication
    enable_replication();

    Enables replication on fenced database. Database needs to be offline.
=cut

sub enable_replication {
    my ($self) = @_;
    my $hostname = $self->{my_instance}->{instance_id};
    die("Database on the fenced node '$hostname' is not offline") if ($self->is_hana_database_online);
    die("System replication '$hostname' is not offline") if ($self->is_primary_node_online);

    my $topology_out = $self->get_hana_topology(hostname => $hostname);
    my %topology = %$topology_out;
    my $cmd = "hdbnsutil -sr_register " .
      "--name=$topology{vhost} " .
      "--remoteHost=$topology{remoteHost} " .
      "--remoteInstance=00 " .
      "--replicationMode=$topology{srmode} " .
      "--operationMode=$topology{op_mode}";

    record_info('CMD Run', $cmd);
    $self->run_cmd(cmd => $cmd, runas => get_required_var("SAP_SIDADM"));
}

=head2 get_replication_info
    get_replication_info();

    Parses "hdbnsutil -sr_state" command output.
    Returns hash of found values converted to lowercase and replaces spaces to underscores.
=cut

sub get_replication_info {
    my ($self) = @_;
    my $output_cmd = $self->run_cmd(cmd => "hdbnsutil -sr_state| grep -E :[^\^]", runas => get_required_var("SAP_SIDADM"));
    record_info("replication info", $output_cmd);
    # Create a hash from hdbnsutil output, convert to lowercase with underscore instead of space.
    my %out = $output_cmd =~ /^?\s?([\/A-z\s]*\S+):\s(\S+)\n/g;
    %out = map { $_ =~ s/\s/_/g; lc $_ } %out;
    return \%out;
}

=head2 get_promoted_instance
    get_promoted_instance();

    Retrieves hostname from currently promoted (Master) database and returns instance data from $self->{instances}.
=cut

sub get_promoted_instance {
    my ($self) = @_;
    my $instances = $self->{instances};
    my $promoted;

    # Identify Site A (Master) and Site B
    foreach my $instance (@$instances) {
        $self->{my_instance} = $instance;
        my $instance_id = $instance->{'instance_id'};
        # Skip instances without HANA db
        next if ($instance_id !~ m/vmhana/);

        my $promoted_id = $self->get_promoted_hostname();
        $promoted = $instance if ($instance_id eq $promoted_id);
    }
    if ($promoted eq "undef" || !defined($promoted)) {
        die("Failed to identify Hana 'PROMOTED' node");
    }
    return $promoted;
}

=head2 wait_for_sync
    wait_for_sync([timeout => $timeout]);

    Wait for replica site to sync data with primary.
    Checks "SAPHanaSR-showAttr" output and ensures replica site has "sync_state" "SOK && PRIM" and no SFAIL.
    Continue after expected output matched three times continually to make sure cluster is synced.
=cut

sub wait_for_sync {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 900);
    my $count = 30;
    my $output_pass = 0;
    my $output_fail = 0;
    record_info("Sync wait", "Waiting for data sync between nodes");

    # Check sync status periodically until ok or timeout
    my $start_time = time;

    while ($count--) {
        die 'HANA replication: node did not sync in time' if $count == 1;
        die 'HANA replication: node is stuck at SFAIL' if $output_fail == 10;
        sleep 30;
        my $ret = $self->run_cmd(cmd => 'SAPHanaSR-showAttr | grep online', proceed_on_failure => 1);
        $output_pass++ if $ret =~ /SOK/ && $ret =~ /PRIM/ && $ret !~ /SFAIL/;
        $output_pass-- if $output_pass == 1 && $ret !~ /SOK/ && $ret !~ /PRIM/ && $ret =~ /SFAIL/;
        $output_fail++ if $ret =~ /SFAIL/;
        $output_fail-- if $output_fail >= 1 && $ret !~ /SFAIL/;
        next if $output_pass < 5;
        last if $output_pass == 5;
        if (time - $start_time > $timeout) {
            record_info("Cluster status", $self->run_cmd(cmd => $crm_mon_cmd));
            record_info("Sync FAIL", "Host replication status: " . $self->run_cmd(cmd => 'SAPHanaSR-showAttr'));
            die("Replication SYNC did not finish within defined timeout. ($timeout sec).");
        }
    }
    record_info("Sync OK", $self->run_cmd(cmd => "SAPHanaSR-showAttr"));
    return 1;
}

=head2 wait_for_pacemaker
    wait_for_pacemaker([timeout => $timeout]);

    Checks status of pacemaker via systemd 'is-active' command an waits for startup.

=cut

sub wait_for_pacemaker {
    my ($self, %args) = @_;
    my $start_time = time;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    my $systemd_cmd = "systemctl --no-pager is-active pacemaker";
    my $pacemaker_state = "";

    while ($pacemaker_state ne "active") {
        sleep 15;
        $pacemaker_state = $self->run_cmd(cmd => $systemd_cmd, proceed_on_failure => 1);
        if (time - $start_time > $timeout) {
            record_info("Pacemaker status", $self->run_cmd(cmd => "systemctl --no-pager status pacemaker"));
            die("Pacemaker did not start within defined timeout");
        }
    }
    return 1;
}

=head2 change_sbd_service_timeout
     $self->change_sbd_service_timeout(timeout => $timeout);

     Overrides timeout for sbd systemd service to a value provided by argument.
     This is done by creating or changing file "/etc/systemd/system/sbd.service.d/sbd_delay_start.conf"

=cut

sub change_sbd_service_timeout() {
    my ($self, $service_timeout) = @_;
    die if !defined($service_timeout);
    my $service_override_dir = "/etc/systemd/system/sbd.service.d/";
    my $service_override_filename = "sbd_delay_start.conf";
    my $service_override_path = $service_override_dir . $service_override_filename;
    my $file_exists = $self->run_cmd(cmd => join(" ", "test", "-e", $service_override_path, ";echo", "\$?"),
        proceed_on_failure => 1,
        quiet => 1);

    # bash return code has inverted value: 0 = file exists
    if (!$file_exists) {
        $self->cloud_file_content_replace($service_override_path,
            '^TimeoutSec=.*',
            "TimeoutSec=$service_timeout");
    }
    else {
        my @content = ('[Service]', "TimeoutSec=$service_timeout");

        $self->run_cmd(cmd => join(" ", "mkdir", "-p", $service_override_dir), quiet => 1);
        $self->run_cmd(cmd => join(" ", "bash", "-c", "\"echo", "'$_'", ">>", $service_override_path, "\""), quiet => 1) foreach @content;
    }
    record_info("Systemd SBD", "Systemd unit timeout for 'sbd.service' set to '$service_timeout'");
}

=head2 setup_sbd_delay_publiccloud
     $self->setup_sbd_delay_publiccloud();

     Set (activate or deactivate) SBD_DELAY_START setting in /etc/sysconfig/sbd.
     Delay is used in case of cluster VM joining cluster too quickly after fencing operation.
     For more information check sbd man page.

     Setting is changed via OpenQA parameter: HA_SBD_START_DELAY
     Possible values:
     "no" - do not set and turn off SBD delay time
     "yes" - sets default SBD value which is calculated from a formula
     "<number of seconds>" - sets specific delay in seconds

     Returns integer representing wait time.

=cut

sub setup_sbd_delay_publiccloud() {
    my ($self) = @_;
    my $delay = get_var('HA_SBD_START_DELAY') // '';

    if ($delay eq '') {
        record_info('SBD delay', 'Skipping, parameter without value');
        # Ensure service timeout is higher than sbd delay time
        $delay = $self->sbd_delay_formula();
        $self->change_sbd_service_timeout($delay + 30);
    }
    else {
        $delay =~ s/(?<![ye])s//g;
        croak("<\$set_delay> value must be either 'yes', 'no' or an integer. Got value: $delay")
          unless looks_like_number($delay) or grep /^$delay$/, qw(yes no);

        $self->cloud_file_content_replace('/etc/sysconfig/sbd', '^SBD_DELAY_START=.*', "SBD_DELAY_START=$delay");
        # service timeout must be higher that startup delay
        $self->change_sbd_service_timeout($self->sbd_delay_formula() + 30);
        record_info('SBD delay', "SBD delay set to: $delay");
    }

    return $delay;
}

=head2 sbd_delay_formula
    $self->sbd_delay_formula();


=cut

sub sbd_delay_formula() {
    my ($self) = @_;
    # all commands below ($corosync_token, $corosync_consensus...) are defined and imported from lib/hacluster.pm
    my %params = (
        'corosync_token' => $self->run_cmd(cmd => $corosync_token),
        'corosync_consensus' => $self->run_cmd(cmd => $corosync_consensus),
        'sbd_watchdog_timeout' => $self->run_cmd(cmd => $sbd_watchdog_timeout),
        'sbd_delay_start' => $self->run_cmd(cmd => $sbd_delay_start),
        'pcmk_delay_max' => get_var('FENCING_MECHANISM') eq 'sbd' ?
          $self->run_cmd(cmd => $pcmk_delay_max) : 30
    );
    my $calculated_delay = calculate_sbd_start_delay(\%params);
    record_info('SBD wait', "Calculated SBD start delay: $calculated_delay");
    return $calculated_delay;
}

=head2 cloud_file_content_replace
    cloud_file_content_replace($filename, $search_pattern, $replace_with);

    Replaces file content direct on PC SUT. Similar to lib/utils.pm file_content_replace()
=cut

sub cloud_file_content_replace() {
    my ($self, $filename, $search_pattern, $replace_with) = @_;
    die("Missing input variable") if (!$filename || !$search_pattern || !$replace_with);
    $self->run_cmd(cmd => sprintf("sed -E 's/%s/%s/g' -i %s", $search_pattern, $replace_with, $filename), quiet => 1);
    return 1;
}

=head2 create_instance_data

    Create and populate a list of publiccloud::instance and publiccloud::provider compatible
    class instances.

=cut

sub create_instance_data {
    my $provider = shift;
    my $class = ref($provider);
    die "Unexpected class type [$class]" unless ($class =~ /^publiccloud::(azure|ec2|gce)/);
    my @instances = ();
    my $inventory_file = qesap_get_inventory(provider => get_required_var('PUBLIC_CLOUD_PROVIDER'));
    my $ypp = YAML::PP->new;
    my $raw_file = script_output("cat $inventory_file");
    my $inventory_data = $ypp->load_string($raw_file)->{all}{children};

    for my $type_label (keys %$inventory_data) {
        my $type_data = $inventory_data->{$type_label}{hosts};
        for my $vm_label (keys %$type_data) {
            my $instance = publiccloud::instance->new(
                public_ip => $type_data->{$vm_label}->{ansible_host},
                instance_id => $vm_label,
                username => get_required_var('PUBLIC_CLOUD_USER'),
                ssh_key => '~/.ssh/id_rsa',
                provider => $provider,
                region => $provider->provider_client->region,
                type => get_required_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
                image_id => $provider->get_image_id());
            push @instances, $instance;
        }
    }
    publiccloud::instances::set_instances(@instances);
    return \@instances;
}

=head2 deployment_name

    Return a string to be used as value for the deployment_name variable
    in the qe-sap-deployment.

=cut

sub deployment_name {
    return qesap_calculate_deployment_name(get_var('PUBLIC_CLOUD_RESOURCE_GROUP', 'qesaposd'));
}

=head2 delete_network_peering

    Delete network peering between SUT created with qe-sa-deployment
    and the IBS Mirror. Function is generic over all the Cloud Providers

=cut

sub delete_network_peering {
    record_info('Peering cleanup', 'Executing peering cleanup (if peering is present)');
    if (is_azure) {
        # Check that required vars are available before deleting the peering
        my $rg = qesap_az_get_resource_group();
        if (get_var('IBSM_RG')) {
            qesap_az_vnet_peering_delete(source_group => $rg, target_group => get_var('IBSM_RG'));
        }
        else {
            record_info('No peering', 'No peering exists, peering destruction skipped');
        }
    }
    elsif (is_ec2) {
        qesap_aws_delete_transit_gateway_vpc_attachment(name => deployment_name() . '*');
    }
}

=head2 create_ansible_playbook_list

    Detects HANA/HA scenario from openQA variables and returns a list of ansible playbooks to include
    in the "ansible: create:" section of config.yaml file.

=cut

sub create_playbook_section_list {
    my ($ha_enabled) = @_;
    my @playbook_list;

    unless (get_var('QESAP_SCC_NO_REGISTER')) {
        # Add registration module as first element - "QESAP_SCC_NO_REGISTER" skips scc registration via ansible
        push @playbook_list, 'registration.yaml -e reg_code=' . get_required_var('SCC_REGCODE_SLES4SAP') . " -e email_address=''";
        # Add "fully patch system" module after registration module and before test start/configuration moudles.
        # Temporary moved inside ha_enabled condition to avoid test without Ansible to fails.
        # To be properly addressed in the caller and fully-patch-system can be placed back out of the if.
        push @playbook_list, 'fully-patch-system.yaml';
    }

    # Prepares Azure native fencing related arguments for 'sap-hana-cluster.yaml' playbook
    my $hana_cluster_playbook = 'sap-hana-cluster.yaml';
    my $azure_native_fencing_args;
    if (get_var('FENCING_MECHANISM') eq 'native') {
        $azure_native_fencing_args = azure_fencing_agents_playbook_args(
            spn_application_id => get_var('_SECRET_AZURE_SPN_APPLICATION_ID'),
            spn_application_password => get_var('_SECRET_AZURE_SPN_APP_PASSWORD')
        );
        $hana_cluster_playbook = join(' ', $hana_cluster_playbook, $azure_native_fencing_args);
    }

    # SLES4SAP/HA related playbooks
    if ($ha_enabled) {
        push @playbook_list, 'pre-cluster.yaml', 'sap-hana-preconfigure.yaml -e use_sapconf=' . get_required_var('USE_SAPCONF');
        push @playbook_list, 'cluster_sbd_prep.yaml' if (check_var('FENCING_MECHANISM', 'sbd'));
        push @playbook_list, qw(
          sap-hana-storage.yaml
          sap-hana-download-media.yaml
          sap-hana-install.yaml
          sap-hana-system-replication.yaml
          sap-hana-system-replication-hooks.yaml
        );
        push @playbook_list, $hana_cluster_playbook;
    }
    return (\@playbook_list);
}

=head3 azure_fencing_agents_playbook_args

    azure_fencing_agents_playbook_args(
        spn_application_id=>$spn_application_id,
        spn_application_password=>$spn_application_password
    );

    Collects data and creates string of arguments that can be supplied to playbook.
    spn_application_id - application ID that allows API access for stonith device
    spn_application_password - password provided for application ID above

=cut

sub azure_fencing_agents_playbook_args {
    my (%args) = @_;
    my $spn_application_id = $args{spn_application_id};
    my $spn_application_password = $args{spn_application_password};
    my $fence_agent_openqa_var = get_var('AZURE_FENCE_AGENT_CONFIGURATION') // 'msi';
    croak "AZURE_FENCE_AGENT_CONFIGURATION contains dubious value: '$fence_agent_openqa_var'" unless
      !$fence_agent_openqa_var or $fence_agent_openqa_var =~ /msi|spn/;
    my $fence_agent_configuration = $fence_agent_openqa_var eq 'spn' ? $fence_agent_openqa_var : 'msi';

    foreach ('spn_application_id', 'spn_application_password') {
        next unless ($fence_agent_configuration eq 'spn');
        croak "Missing '$_' argument" unless defined($args{$_});
    }

    my $playbook_opts = "-e azure_identity_management=$fence_agent_configuration";
    $playbook_opts = join(' ', $playbook_opts,
        "-e spn_application_id=$spn_application_id",
        "-e spn_application_password=$spn_application_password") if $fence_agent_configuration eq 'spn';

    return ($playbook_opts);
}

=head2 create_hana_vars_section

    Detects HANA/HA scenario from openQA variables and creates "terraform: variables:" section in config.yaml file.

=cut

sub create_hana_vars_section {
    my ($ha_enabled) = @_;
    # Cluster related setup
    my %hana_vars;
    if ($ha_enabled == 1) {
        $hana_vars{sap_hana_install_software_directory} = get_required_var('HANA_MEDIA');
        $hana_vars{sap_hana_install_master_password} = get_required_var('_HANA_MASTER_PW');
        $hana_vars{sap_hana_install_sid} = get_required_var('INSTANCE_SID');
        $hana_vars{sap_hana_install_instance_number} = get_required_var('INSTANCE_ID');
        $hana_vars{sap_domain} = get_var('SAP_DOMAIN', 'qesap.example.com');
        $hana_vars{primary_site} = get_var('HANA_PRIMARY_SITE', 'site_a');
        $hana_vars{secondary_site} = get_var('HANA_SECONDARY_SITE', 'site_b');
        set_var('SAP_SIDADM', lc(get_var('INSTANCE_SID') . 'adm'));
    }
    return (\%hana_vars);
}

=head2 display_full_status

    $self->display_full_status()

    Displays most useful debugging info about cluster status, database status within a 'record_info' test entry.

=cut

sub display_full_status {
    my ($self) = @_;
    my $vm_name = $self->{my_instance}{instance_id};
    my $crm_status = join("\n", "\n### CRM STATUS ###", $self->run_cmd(cmd => 'crm status', proceed_on_failure => 1));
    my $saphanasr_showattr = join("\n", "\n### HANA REPLICATION INFO ###", $self->run_cmd(cmd => 'SAPHanaSR-showAttr', proceed_on_failure => 1));

    my $final_message = join("\n", $crm_status, $saphanasr_showattr);
    record_info("STATUS $vm_name", $final_message);
}

=head2 list_cluster_nodes

    $self->list_cluster_nodes()

    Returns list of hostnames that are part of a cluster using cmr shell command from one of the cluster nodes.

=cut

sub list_cluster_nodes {
    my ($self) = @_;
    my $instances = $self->{instances};
    my @cluster_nodes;

    foreach my $instance (@$instances) {
        $self->{my_instance} = $instance;
        # check if node is part of the cluster
        next unless ($self->run_cmd(cmd => 'crm status', rc_only => 1, quiet => 1) == 0);
        @cluster_nodes = split(/[\n\s]/, $self->run_cmd(cmd => 'crm node server'));    # list of cluster node members
        return \@cluster_nodes;
    }
    die 'None of the hosts are currently part of existing cluster' unless @cluster_nodes;
}

=head2 get_hana_database_status

    Run a query to the hana database, parses "hdbsql" command output and check if the connection still is alive.
    Returns 1 if the response from hana database is online, 0 otherwise

=cut

sub get_hana_database_status {
    my ($self, $password_db, $instance_id) = @_;
    my $hdb_cmd = "hdbsql -u SYSTEM -p $password_db -i $instance_id 'SELECT * FROM SYS.M_DATABASES;'";
    my $output_cmd = $self->run_cmd(cmd => $hdb_cmd, runas => get_required_var("SAP_SIDADM"), proceed_on_failure => 1);

    if ($output_cmd =~ /Connection failed/) {
        record_info('HANA DB OFFLINE', "Hana database in primary node is offline. Here the output \n$output_cmd");
        return 0;
    }
    return 1;
}

=head2 is_hana_database_online

    Setup a timeout and check the hana database status is offline and there is not connection.
    if the connection still is online run a wait and try again to get the status.
    Returns 1 if the output of the hana database is online, 0 means that hana database is offline

=over 2

=item B<TIMEOUT> - default 900
=item B<TOTAL_CONSECUTIVE_PASSES> - default 5

=back
=cut

sub is_hana_database_online {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 900);
    my $total_consecutive_passes = ($args{total_consecutive_passes} // 5);
    my $instance_id = get_required_var('INSTANCE_ID');

    my $db_status = -1;
    my $consecutive_passes = 0;
    my $password_db = get_required_var('_HANA_MASTER_PW');
    my $start_time = time;
    my $hdb_cmd = "hdbsql -u SYSTEM -p $password_db -i $instance_id 'SELECT * FROM SYS.M_DATABASES;'";

    while ($consecutive_passes < $total_consecutive_passes) {
        $db_status = $self->get_hana_database_status($password_db, $instance_id);
        if (time - $start_time > $timeout) {
            record_info("Hana database after timeout", $self->run_cmd(cmd => $hdb_cmd));
            die("Hana database is still online");
        }
        if ($db_status == 0) {
            last;
        }
        sleep 30;
        ++$consecutive_passes;
    }
    return $db_status;
}

=head2 is_primary_node_online

    Check if primary node in a hana cluster is offline.
    Returns if primary node status is offline with 0 and 1 online

=cut

sub is_primary_node_online {
    my ($self, %args) = @_;
    my $sapadmin = lc(get_required_var('INSTANCE_SID')) . 'adm';

    # Wait by default for 5 minutes
    my $time_to_wait = 300;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    my $cmd = "python exe/python_support/systemReplicationStatus.py";
    my $output = "";

    # Loop until is not primary the vm01 or timeout is reached
    while ($time_to_wait > 0) {
        $output = $self->run_cmd(cmd => $cmd, runas => $sapadmin, timeout => $timeout, proceed_on_failure => 1);
        if ($output !~ /mode:[\r\n\s]+PRIMARY/) {
            record_info('SYSTEM REPLICATION STATUS', "System replication status in pimary node.\n$@");
            return 0;
        }
        $time_to_wait -= 10;
        sleep 10;
    }
    record_info('SYSTEM REPLICATION STATUS', "System replication status in primary node.\n$output");
    return 1;
}

1;
