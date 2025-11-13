# SUSE's openQA tests
#
# Copyright 2022 - 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Library used for SLES4SAP public cloud deployment and tests
#
# Note: Subroutines executing commands on remote host (using "run_cmd" or "run_ssh_command") require
# to have $self->{my_instance} defined.
# $self->{my_instance} defines what is the target instance to execute code on. It is acquired from
# data located in "@instances" and produced by deployment test modules.

package sles4sap_publiccloud;

use base 'publiccloud::basetest';
use strict;
use JSON;
use warnings FATAL => 'all';
use Exporter 'import';
use Scalar::Util qw(looks_like_number);
use List::MoreUtils qw(uniq);
use Carp qw(croak);
use YAML::PP;
use testapi;
use utils qw(file_content_replace);
use serial_terminal qw(serial_term_prompt);
use version_utils qw(check_version is_sle);
use hacluster;
use sles4sap::qesap::qesapdeployment;
use sles4sap::qesap::aws;
use publiccloud::utils;
use publiccloud::provider;
use publiccloud::ssh_interactive qw(select_host_console);
use publiccloud::instance;
use sles4sap;
use saputils;

our @EXPORT = qw(
  run_cmd
  run_cmd_retry
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
  create_playbook_section_list
  create_hana_vars_section
  azure_fencing_agents_playbook_args
  display_full_status
  list_cluster_nodes
  sles4sap_cleanup
  is_hana_database_online
  get_hana_database_status
  is_primary_node_online
  pacemaker_version
  saphanasr_showAttr_version
  get_hana_site_names
  wait_for_cluster
  wait_for_zypper
  check_zypper_ref
  wait_for_idle
);

=head1 DESCRIPTION

    Package with common methods and default or constant  values for sles4sap tests in the cloud

=head2 run_cmd
    run_cmd(cmd => 'command', [runas => 'user', timeout => 60]);

    Runs a command C<cmd> via ssh in the given VM and log the output.
    All commands are executed through C<sudo>.
    If 'runas' defined, command will be executed as specified user,
    otherwise it will be executed as root.

=over

=item B<cmd> - command string to be executed remotely

=item B<timeout> - command execution timeout

=item B<title> - used in record_info

=item B<runas> - pre-pend the command with su to execute it as specific user

=item B<...> - pass through all other arguments supported by run_ssh_command

=back
=cut

sub run_cmd {
    my ($self, %args) = @_;
    croak('Argument <cmd> missing') unless $args{cmd};
    croak('$self->{my_instance} is not defined. Check module Description for details')
      unless $self->{my_instance};
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);
    my $title = $args{title} // $args{cmd};
    $title =~ s/[[:blank:]].+// unless defined $args{title};
    my $cmd = defined($args{runas}) ? "su - $args{runas} -c '$args{cmd}'" : "$args{cmd}";
    # Without cleaning up variables SSH commands get executed under wrong user
    delete($args{cmd});
    delete($args{title});
    delete($args{timeout});
    delete($args{runas});

    $self->{my_instance}->update_instance_ip();
    $self->{my_instance}->wait_for_ssh(timeout => $timeout);
    my $out = $self->{my_instance}->run_ssh_command(cmd => "sudo $cmd", timeout => $timeout, %args);
    record_info("$title output - $self->{my_instance}->{instance_id}", $out) unless ($timeout == 0 or $args{quiet} or $args{rc_only});
    return $out;
}

=head2 run_cmd_retry
    run_cmd_retry(cmd => 'command', [retry => 3, timeout => 60, delay => 10]);

    Runs a command C<cmd> via ssh in the given VM and log the output.
    If command fails or C<timeout> is reached, then the command will be
    retried for C<retry> times, with C<delay> seconds of interval in between.

=over

=item B<cmd> - command string to be executed remotely

=item B<timeout> - command execution timeout

=item B<retry> - number of retry attempts

=item B<delay> - idle time between retry attempts

=item B<...> - pass through all other arguments supported by run_cmd

=back
=cut

sub run_cmd_retry {
    my ($self, %args) = @_;
    my $timeout = delete $args{timeout} // 60;
    my $retry = delete $args{retry} // 3;
    my $delay = delete $args{delay} // 10;
    delete($args{proceed_on_failure});

    for (1 .. $retry) {
        my $ret = eval { $self->run_cmd(timeout => $timeout, proceed_on_failure => 0, %args); };
        return $ret if (defined $ret);
        sleep $delay;
        record_soft_failure('jsc#TEAM-10485 SSH timeout or failure, retrying');
    }
    die('Maximum number of SSH retry attempts exceeded');
}

=head2 get_promoted_hostname()
    get_promoted_hostname();

    Checks and returns hostname of HANA promoted node according to crm shell output.
=cut

sub get_promoted_hostname {
    my ($self) = @_;
    my $master_resource_type = get_var('USE_SAP_HANA_SR_ANGI') ? 'mst' : 'msl';
    my $hana_resource = join('_',
        $master_resource_type,
        'SAPHanaCtl',
        get_required_var('INSTANCE_SID'),
        'HDB' . get_required_var('INSTANCE_ID'));

    my $resource_output = $self->run_cmd(cmd => 'crm resource status ' . $hana_resource, quiet => 1);
    record_info('crm out', $resource_output);
    my @master = $resource_output =~ /:\s(\S+)\sMaster/g;
    if (scalar @master != 1) {
        diag("Master database not found or command returned abnormal output.\n
        Check 'crm resource status' command output below:\n");
        diag($resource_output);
        die('Master database was not found, check autoinst.log');
    }

    return join('', @master);
}

=head2 sles4sap_cleanup

    Clean up Network peering and qesap deployment
    This method does not internally die and try to execute
    terraform destroy in any case.
    Return 0 if no internal error.

=over

=item B<cleanup_called> - flag to indicate cleanup status

=item B<ansible_present> - flag to indicate ansible has need executed as part of the deployment

=back
=cut

sub sles4sap_cleanup {
    my ($self, %args) = @_;
    record_info(
        'Cleanup',
        join(' ',
            'cleanup_called:', $args{cleanup_called} // 'undefined',
            'ansible_present:', $args{ansible_present} // 'undefined'));

    # Do not run destroy if already executed
    return 0 if ($args{cleanup_called});

    # If there's an open ssh connection to the VMs, return to host console first
    # Useful for tests that use ssh_interactive modules
    select_host_console(force => 1) if (get_var('MR_TEST', ''));

    # ETX is the same as pressing Ctrl-C on a terminal,
    # make sure the serial terminal is NOT blocked
    type_string('', terminate_with => 'ETX');

    qesap_cluster_logs();

    # setting SUPPORTCONFIG=0 will skip supportconfig log collection in both PASS and FAIL jobs
    # setting SUPPORTCONFIG=1 will collect supportconfig logs in both PASS and FAIL jobs
    # not setting SUPPORTCONFIG at all will only collect logs in case of failure
    if (!check_var('SUPPORTCONFIG', '0') && (get_var('SUPPORTCONFIG') || (($self->{result} // '') eq 'fail'))) {
        qesap_supportconfig_logs(provider => get_required_var('PUBLIC_CLOUD_PROVIDER'));
    }

    qesap_upload_logs();
    upload_logs('/var/tmp/ssh_sut.log', failok => 1, log_name => 'ssh_sut.log.txt');

    my @cmd_list;

    # Only run the Ansible de-register if Ansible has been executed
    push(@cmd_list, 'ansible') if ($args{ansible_present});

    # Regardless of Ansible result, Terraform destroy
    # must be executed.
    push(@cmd_list, 'terraform');

    my $ret = 0;
    for my $command (@cmd_list) {
        record_info('Cleanup', "Executing $command cleanup");

        # 3 attempts for both terraform and ansible clean-up
        for (1 .. 3) {
            my @cleanup_cmd_rc = qesap_execute(
                verbose => '--verbose',
                logname => join('_', 'qesap', $command, 'destroy', $_, 'log.txt'),
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
            $ret = 1 if $_ == 3 && $cleanup_cmd_rc[0];
        }
    }
    record_info('Cleanup finished', "ret:$ret");
    return $ret;
}

=head2 get_hana_topology
    Parses command output, returns hash of hashes containing values for each host.

=cut

sub get_hana_topology {
    my ($self) = @_;
    my $output_format = get_var('USE_SAP_HANA_SR_ANGI') ? 'json' : 'script';
    $self->wait_for_idle(timeout => 240);
    my $cmd_out = $self->run_cmd_retry(cmd => "SAPHanaSR-showAttr --format=$output_format", quiet => 1);
    return calculate_hana_topology(input_format => $output_format, input => $cmd_out);
}

=head2 is_hana_online
    is_hana_online([timeout => 120, wait_for_start => 'false']);

    Check if hana DB is online.

=over

=item B<wait_for_start> - Define 'wait_for_start' to wait for DB to start.

=item B<timeout> - timeout for the wait of the online state

=back
=cut

sub is_hana_online {
    my ($self, %args) = @_;
    $args{wait_for_start} //= 0;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $start_time = time;
    my $consecutive_passes = 0;
    my $db_status;

    while ($consecutive_passes < 3) {
        $db_status = $self->get_replication_info()->{online} eq "true" ? 1 : 0;
        return $db_status unless $args{wait_for_start};

        # Reset pass counter in case of fail.
        $consecutive_passes = $db_status ? ++$consecutive_passes : 0;
        die("DB did not start within defined timeout: $timeout s") if (time - $start_time > $timeout);
        sleep 10;
    }
    return $db_status;
}

=head2 is_hana_resource_running
    is_hana_resource_running([quiet => 0]);

    Checks if resource msl_SAPHanaCtl_* is running on given node.

=over

=item B<quiet> - if set, returns the value without recording info (default: 0)

=back  
=cut

sub is_hana_resource_running {
    my ($self, %args) = @_;
    $args{quiet} //= 0;
    my $hostname = $self->{my_instance}->{instance_id};
    my $master_resource_type = get_var('USE_SAP_HANA_SR_ANGI') ? 'mst' : 'msl';
    my $hana_resource = join('_',
        $master_resource_type,
        'SAPHanaCtl',
        get_required_var('INSTANCE_SID'),
        'HDB' . get_required_var('INSTANCE_ID'));

    my $resource_output = $self->run_cmd(cmd => "crm resource status $hana_resource", quiet => 1);
    if ($resource_output =~ /is running on: \Q$hostname\E/) {
        record_info('Node status', "$hana_resource is running on $hostname") unless $args{quiet};
        return 1;
    } else {
        record_info('Node status', "$hana_resource is NOT running on $hostname") unless $args{quiet};
        return 0;
    }
}

=head2 is_hana_node_up
    is_hana_node_up($my_instance, [timeout => 900]);

    Waits until 'is-system-running' returns successfully on the target instance.

=over

=item B<instance> - the instance the test needs to wait for

=item B<timeout> - how much time to wait for before aborting

=back  
=cut

sub wait_hana_node_up {
    my ($instance, %args) = @_;
    $args{timeout} //= 900;
    my $start_time = time();
    my $out;
    while ((time() - $start_time) < $args{timeout}) {
        $out = $instance->run_ssh_command(
            cmd => 'sudo systemctl is-system-running',
            timeout => 5,
            proceed_on_failure => 1);
        return if ($out =~ m/running/);
        if ($out =~ m/degraded/) {
            my $failed_service = $instance->run_ssh_command(cmd => 'sudo systemctl --failed', timeout => 600, proceed_on_failure => 1);
            if ($out =~ /degraded/ && $failed_service =~ /guestregister/) {
                record_soft_failure('bsc#1238152 - Restart guestregister service');
                $instance->run_ssh_command(cmd => 'sudo systemctl restart guestregister.service', timeout => 600, proceed_on_failure => 1);
            }
        }
        record_info('WAIT_FOR_SYSTEM', "System state: $out");
        sleep 10;
    }
    die('Timeout reached. is-system-running returns: ' . $out);
}

=head2 stop_hana
    stop_hana([timeout => $timeout, method => $method]);

    Stops HANA database using default or specified method.
    "stop" - stops database using "HDB stop" command.
    "kill" - kills database processes using "HDB -kill" command.
    "crash" - crashes entire OS using "/proc/sysrq-trigger" method.

=over

=item B<method> - Allow to specify a specific stop method

=item B<timeout> - only used for stop and kill

=back
=cut

sub stop_hana {
    my ($self, %args) = @_;
    $args{method} //= 'stop';
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    my %commands = (
        stop => 'HDB stop',
        kill => 'HDB kill -x',
        # echo b > /proc/sysrq-trigger is for crashing the remote node
        # This also work in conjunction with ssh -fn arguments
        crash => 'sudo su -c "echo b > /proc/sysrq-trigger &"'
    );
    croak("HANA stop method '$args{method}' unknown.") unless $commands{$args{method}};

    my $cmd = $commands{$args{method}};

    # Wait for data sync before stopping DB
    $self->wait_for_sync();

    record_info('Stopping HANA', "CMD:$cmd");
    if ($args{method} eq 'crash') {
        # Crash needs to be executed as root and wait for host reboot

        # Ensure the remote node is in a normal state before to trigger the crash
        $self->{my_instance}->update_instance_ip();
        $self->{my_instance}->wait_for_ssh(timeout => $timeout, scan_ssh_host_key => 1);

        $self->{my_instance}->run_ssh_command(cmd => 'sudo su -c sync', timeout => $timeout);

        # Create a local copy of ssh_opts and extend it for the crash command.
        # Extension is on top of values defined in the current instance class $self->{my_instance}->ssh_opts
        # which in HanaSR tests are set with default values in sles4sap_publiccloud_basetest::set_cli_ssh_opts.
        # -f requests ssh to go to background just before command execution
        # -n is about stdin redirection and it is needed by -f to work
        my $crash_ssh_opts = $self->{my_instance}->ssh_opts . ' -fn -o ServerAliveInterval=2';

        $self->{my_instance}->run_ssh_command(
            cmd => $cmd,
            # This timeout is to ensure the run_ssh_command is executed in a reasonable amount of time.
            # It is not about how much time the crash is expected to take in the SUT.
            # Also consider that internally run_ssh_command is using this value for two different guard mechanisms.
            timeout => 10,
            # This test does not care about output,
            # setting this in conjunction with timeout >0 result in the internal implementation of
            # run_ssh_command to use script_run
            rc_only => 1,
            ssh_opts => $crash_ssh_opts);

        # Wait till SSH port 22 disappear
        record_info('Wait ssh disappear', 'START');
        my $start_time = time();
        my $exit_code;
        my $nc_error_occurrence = 0;
        while (((time() - $start_time) < 900) and ($nc_error_occurrence < 5)) {
            $exit_code = script_run('nc -vz -w 1 ' . $self->{my_instance}->{public_ip} . ' 22', quiet => 1);
            $nc_error_occurrence += 1 if (!defined($exit_code) or $exit_code ne 0);
        }
        my $end_msg = join("\n",
            'END',
            "started at $start_time",
            'elapsed:' . (time() - $start_time),
            "nc_error_occurrence:$nc_error_occurrence",
            "last exit_code:$exit_code");
        record_info('Wait ssh disappear', $end_msg);

        # wait for node to be ready
        wait_hana_node_up($self->{my_instance}, timeout => 900);
        record_info('Wait ssh is back again');
    }
    else {
        my $sapadmin = lc(get_required_var('INSTANCE_SID')) . 'adm';
        $self->run_cmd(cmd => $cmd, runas => $sapadmin, timeout => $timeout);
        $self->{my_instance}->update_instance_ip();
        $self->{my_instance}->wait_for_ssh(username => 'cloudadmin', scan_ssh_host_key => 1);
    }
}

=head2 start_hana
    start_hana([timeout => 60]);

    Start HANA DB using "HDB start" command
=cut

sub start_hana {
    my ($self) = @_;
    $self->run_cmd(cmd => 'HDB start', runas => get_required_var('SAP_SIDADM'));
}

=head2 cleanup_resource
    cleanup_resource([timeout => 60]);

    Cleanup resource 'msl_SAPHanaCtl_*', wait for DB start automatically.

=over

=item B<timeout> - timeout for waiting resource to start

=back
=cut

sub cleanup_resource {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    my @errors = (
        qr/Aborting because no messages received in \d+ seconds/,
        qr/Error performing operation: Timeout occurred/
    );
    my $retry = '3';
    my $out = undef;

    # Retry when running crm command with issue, refer to TEAM-10483
    while ($retry) {
        $out = $self->run_cmd(cmd => 'crm resource cleanup', proceed_on_failure => 1);
        last if (!grep { $out =~ /$_/ } @errors);
        $retry--;
        sleep 5;
    }
    die "Clean up resource failed:\n$out" if ($retry == 0);

    # Wait for resource to start
    my $start_time = time;
    while ($self->is_hana_resource_running() == 0) {
        if (time - $start_time > $timeout) {
            record_info('Cluster status', $self->run_cmd(cmd => $crm_mon_cmd));
            die("cleanup_resource [ERROR] Resource did not start within defined timeout. ($timeout sec).");
        }
        sleep 30;
    }
    # Show the status of resource after cleanup resource
    record_info('Cluster status after cleanup resource', $self->run_cmd(cmd => $crm_mon_cmd));
}

=head2 check_takeover
    check_takeover();

    Checks takeover status and waits for finish until successful or reaches timeout.
=cut

sub check_takeover {
    my ($self) = @_;
    my $hostname = $self->{my_instance}->{instance_id};    # local hostname
    die("check_takeover [ERROR] Database on the fenced node '$hostname' isn't offline") if ($self->is_hana_database_online);
    die("check_takeover [ERROR] System replication '$hostname' isn't offline") if ($self->is_primary_node_online);
    my $retry_count = 0;    # counter of retries
    my $vhost;    # hostname from 'vhost' value of 'Host' key of SAPHanaSR-showAttr topology
    my $sync_state;    # status of the sync from 'srPoll' value of 'Site' key of SAPHanaSR-showAttr topology

  TAKEOVER_LOOP: while (1) {
        my $topology = $self->get_hana_topology();
        $retry_count++;
        for my $site (keys %{$topology->{Site}}) {
            die("check_takeover [ERROR] Missing 'srPoll' field in topology output of Site->$site")
              unless defined($topology->{Site}->{$site}->{srPoll});
            # As 'vhost' value is not part of the 'Site' key we need to pair it with corect 'Host' key
            for my $host (keys %{$topology->{Host}}) {
                die("check_takeover [ERROR] Missing 'vhost' field in topology output of $host")
                  unless defined($topology->{Host}->{$host}->{vhost});
                $vhost = $topology->{Host}->{$host}->{vhost} if ($topology->{Host}->{$host}->{site} eq $site);
                $sync_state = $topology->{Site}->{$site}->{srPoll} if ($topology->{Host}->{$host}->{site} eq $site);
            }
            record_info('Cluster Host', join("\n",
                    "vhost: $vhost compared with $hostname",
                    "sync_state: $sync_state compared with PRIM"));
            if ($vhost ne $hostname && $sync_state eq "PRIM") {
                record_info('Takeover status:', "Takeover complete to node '$vhost'");
                last TAKEOVER_LOOP;
            }
        }
        die('check_takeover [ERROR] Test failed: takeover failed to complete.') if ($retry_count > 40);
        sleep 30;
    }

    return 1;
}

=head2 enable_replication
    enable_replication([site_name => 'site_a', hana_inn => '10' ]);

    Re-enables replication on the previously fenced database node. Database must be offline.
    Dies if the the given <site name> doesn't correspond with the SAPHanaSR topology local site name
    Optionaly the 'hana_innstance_id' could be provided for better reliability

=over

=item B<site_name> - local HANA site name of the site to be registered

=item B<hana_inn> - optional HANA instance number to be registered

=back
=cut

sub enable_replication {
    my ($self, %args) = @_;
    croak('enable_replication [ERROR] Argument <site_name> missing') unless $args{site_name};
    my $hostname = $self->{my_instance}->{instance_id};
    my $remote_host;    # HANA site remote host to register
    my $site = $args{site_name};    # HANA node name
    my $sr_mode;    # HANA replication mode from SAPHanaSR-showAttr
    my $op_mode;    # HANA SR operations mode from SAPHanaSR-showAttr
    my $hana_inn;    # HANA instance number

    die("enable_replication [ERROR] Database on the fenced node '$hostname' is not offline") if ($self->is_hana_database_online);
    die("enable_replication [ERROR] System replication '$hostname' is not offline") if ($self->is_primary_node_online);

    my $topology = $self->get_hana_topology();
    $hana_inn = $args{hana_inn} if defined($args{hana_inn});

    # Getting 'sr_mode' and 'op_mode' from the SAPHanaSR topology
    foreach (qw(srMode opMode)) { die("enable_replication [ERROR] Missing '$_' field in topology output of Site->$site") unless defined($topology->{Site}->{$site}->{$_}); }
    $sr_mode = $topology->{Site}->{$site}->{srMode};
    $op_mode = $topology->{Site}->{$site}->{opMode};

    # Getting remote host from the SAPHanaSR topology as 'remote_host' key is now omitted from the 'SAPHanaSR-showAttr' output
    for my $host (keys %{$topology->{Host}}) {
        die("enable_replication [ERROR] Missing 'vhost' field in topology output of $host") unless defined($topology->{Host}->{$host}->{vhost});
        $remote_host = $topology->{Host}->{$host}->{vhost} if ($hostname ne $topology->{Host}->{$host}->{vhost} && $site ne $topology->{Host}->{$host}->{site});
        last if defined($remote_host);
    }
    # Dies if the given <site name> doesn't correspond with the SAPHanaSR topology like if given site name is not a local one.
    die("enable_replication [ERROR] Remote host could not be determined. Is <site_name>: $site at <hostname>: $hostname really local?") unless defined($remote_host);

   # The instance number couldn't be hard-coded, so if not set from SETTINGS we could try to determine it from the cluster resource name of 'mst_.*' or 'msl_.*'
    # where it should be the last 2 characters for example it's '10' in 'msl_SAPHana_HA1_HDB10'
    unless ($hana_inn) {
        for my $resource (keys %{$topology->{Resource}}) {
            $hana_inn = substr($resource, -2) if (substr($resource, 0, 3) eq 'mst' or substr($resource, 0, 3) eq 'msl');
            if (defined $hana_inn) { record_info('Instance number was not provided and is determined from the name of th resource', $resource) }
            last if defined($hana_inn);
        }
        die('enable_replication [ERROR] Instance number could not be determined from the names of listed resources') unless defined($hana_inn);
    }


    my $cmd = join(' ', 'hdbnsutil -sr_register',
        '--name=' . $site,
        '--remoteHost=' . $remote_host,
        '--remoteInstance=' . $hana_inn,
        '--replicationMode=' . $sr_mode,
        '--operationMode=' . $op_mode);

    record_info('CMD Run', $cmd);
    $self->run_cmd(cmd => $cmd, runas => get_required_var('SAP_SIDADM'));
}

=head2 get_replication_info
    get_replication_info();

    Parses "hdbnsutil -sr_state" command output.
    Returns hash of found values converted to lowercase and replaces spaces to underscores.
=cut

sub get_replication_info {
    my ($self) = @_;
    my $output_cmd = $self->run_cmd(cmd => 'hdbnsutil -sr_state 2>&1', runas => get_required_var('SAP_SIDADM'));
    $output_cmd = join "\n", grep /:[^\^]/, split /\n/, $output_cmd;
    record_info('Replication info', $output_cmd);
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
    if ($promoted eq 'undef' || !defined($promoted)) {
        die('get_promoted_instance [ERROR] Failed to identify HANA "PROMOTED" node');
    }
    return $promoted;
}

=head2 wait_for_sync
    wait_for_sync([timeout => $timeout]);

    Wait for replica site to sync data with primary.
    Checks "SAPHanaSR-showAttr" output and ensures replica site has "sync_state" "SOK && PRIM" and no SFAIL.
     Continue after expected output matched N times continually to make sure cluster is synced.

    Expected conditions:
     - Both primary and replica must be online.
     - primary must have sync_state 'PRIM'
     - primary must have clone_state 'PROMOTED'
     - replica must have sync_state 'SOK'  - this means data is in sync
     - replica must have clone_state 'DEMOTED'
     - site order does not matter

=over

=item B<timeout> - timeout for waiting sync state

=back
=cut

sub wait_for_sync {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 900);
    # If pacemaker >= 2.1.7 then 'online_str' is now based on 'lss' score where 4 means OK
    # Otherwise it's set to the legacy 'online'
    my $online_str = check_version('>=2.1.7', $self->pacemaker_version()) ? '4' : 'online';
    my $output_pass = 0;

    record_info('Wait for sync', "Waiting for data sync between nodes. online_str=$online_str timeout=$timeout");

    # Check sync status periodically until OK for 5 times in a row or timeout
    my $start_time = time;
    while (time - $start_time < $timeout) {
        # call SAPHanaSR-showAttr to get current topology, validate the output, calculate the score.
        # Not OK cluster result in score reset to zero
        $output_pass = check_hana_topology(input => $self->get_hana_topology(), node_state_match => $online_str) ? $output_pass + 1 : 0;
        last if $output_pass == 5;
        sleep 30;
    }
    if ($output_pass < 5) {
        record_info('Sync FAIL', 'Host replication status: ' . $self->run_cmd(cmd => 'SAPHanaSR-showAttr'));
        record_info('Cluster status', $self->run_cmd(cmd => $crm_mon_cmd));
        die("wait_for_sync [ERROR] Replication SYNC did not finish within defined timeout. ($timeout sec).");
    }
}

=head2 wait_for_pacemaker
    wait_for_pacemaker([timeout => $timeout]);

    Checks status of pacemaker via systemd 'is-active' command an waits for startup.

=over

=item B<timeout> - timeout for waiting for pacemaker service

=back
=cut

sub wait_for_pacemaker {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    my $start_time = time;
    my $systemd_cmd = 'systemctl --no-pager is-active pacemaker';
    my $pacemaker_state = '';

    while ($pacemaker_state ne 'active') {
        sleep 15;
        $pacemaker_state = $self->run_cmd(cmd => $systemd_cmd, proceed_on_failure => 1);
        if (time - $start_time > $timeout) {
            record_info('Pacemaker status', $self->run_cmd(cmd => 'systemctl --no-pager status pacemaker'));
            die('wait_for_pacemaker [ERROR] Pacemaker did not start within defined timeout');
        }
    }
    return 1;
}

=head2 change_sbd_service_timeout
     $self->change_sbd_service_timeout(service_timeout => '30');

     Overrides timeout for sbd systemd service to a value provided by argument.
     This is done by creating or changing file "/etc/systemd/system/sbd.service.d/sbd_delay_start.conf"

=over

=item B<service_timeout> - value for the TimeoutSec setting

=back
=cut

sub change_sbd_service_timeout() {
    my ($self, %args) = @_;
    croak('change_sbd_service_timeout [ERROR] Argument <service_timeout> missing') unless $args{service_timeout};

    my $service_override_dir = '/etc/systemd/system/sbd.service.d/';
    my $service_override_filename = 'sbd_delay_start.conf';
    my $service_override_path = $service_override_dir . $service_override_filename;
    my $file_exists = $self->run_cmd(cmd => join(' ', 'test', '-e', $service_override_path, ';echo', '\$?'),
        proceed_on_failure => 1,
        quiet => 1);

    # bash return code has inverted value: 0 = file exists
    if (!$file_exists) {
        $self->cloud_file_content_replace(filename => $service_override_path,
            search_pattern => '^TimeoutSec=.*',
            replace_with => "TimeoutSec=$args{service_timeout}");
    }
    else {
        my @content = ('[Service]', "TimeoutSec=$args{service_timeout}");

        $self->run_cmd(cmd => join(' ', 'mkdir', '-p', $service_override_dir), quiet => 1);
        $self->run_cmd(cmd => join(' ', 'bash', '-c', '"echo', "'$_'", '>>', $service_override_path, '"'), quiet => 1) foreach @content;
    }
    record_info('Systemd SBD', "Systemd unit timeout for 'sbd.service' set to '$args{service_timeout}'");
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
        $self->change_sbd_service_timeout(service_timeout => $delay + 30);
    }
    else {
        $delay =~ s/(?<![ye])s//g;
        croak("setup_sbd_delay_publiccloud [ERROR] <\$set_delay> value must be either 'yes', 'no' or an integer. Got value: $delay")
          unless looks_like_number($delay) or grep /^$delay$/, qw(yes no);
        $self->cloud_file_content_replace(filename => '/etc/sysconfig/sbd', search_pattern => '^SBD_DELAY_START=.*', replace_with => "SBD_DELAY_START=$delay");
        # service timeout must be higher that start-up delay
        $self->change_sbd_service_timeout(service_timeout => $self->sbd_delay_formula() + 30);
        record_info('SBD delay', "SBD delay set to: $delay");
    }

    return $delay;
}

=head2 sbd_delay_formula
    $self->sbd_delay_formula();

    return calculated sbd delay

=cut

sub sbd_delay_formula() {
    my ($self) = @_;
    # all commands below ($corosync_token, $corosync_consensus...)
    # are defined and imported from lib/hacluster.pm
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
    cloud_file_content_replace(filename => $filename, search_pattern => $search_pattern, replace_with => $replace_with);

    Replaces file content direct on PC SUT. Similar to lib/utils.pm file_content_replace()

=over

=item B<filename> - file location

=item B<search_pattern> - search pattern

=item B<replace_with> - string to replace

=back
=cut

sub cloud_file_content_replace() {
    my ($self, %args) = @_;
    foreach (qw(filename search_pattern replace_with)) {
        croak("Argument < $_ > missing") unless $args{$_}; }
    $self->run_cmd(cmd => sprintf("sed -E 's/%s/%s/g' -i %s", $args{search_pattern}, $args{replace_with}, $args{filename}), quiet => 1);
}

=head2 create_instance_data

    Create and populate a list of publiccloud::instance and publiccloud::provider compatible
    class instances.

=over

=item B<provider> - Instance of PC object "provider", the one usually created by provider_factory()

=back
=cut

sub create_instance_data {
    my (%args) = @_;
    croak('Argument <provider> missing') unless $args{provider};
    my $class_type = ref($args{provider});
    croak("Unexpected class type [$class_type]") unless $class_type =~ /^publiccloud::(azure|ec2|gce)/;
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
                ssh_key => get_ssh_private_key_path(),
                provider => $args{provider},
                region => $args{provider}->provider_client->region,
                type => get_required_var('PUBLIC_CLOUD_INSTANCE_TYPE'),
                image_id => $args{provider}->get_image_id());
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

=head2 create_ansible_playbook_list

    Detects HANA/HA scenario from function arguments and returns a list of ansible playbooks to include
    in the "ansible: create:" section of config.yaml file.

=over

=item B<ha_enabled> - Enable the installation of HANA and the cluster configuration

=item B<registration> - select registration mode, possible values are
                          * registercloudguest (default)
                          * suseconnect
                          * noreg skip scheduling of register.yaml at all

=item B<scc_code> - registration code

=item B<ltss> - name and reg_code for LTSS extension to register.
                This argument is a two element comma separated list string.
                Like: 'SLES-LTSS-Extended-Security/12.5/x86_64,123456789'
                First string before the comma has to be a valid SCC extension name, later used by Ansible
                as argument for SUSEConnect or registercloudguest argument.
                Second string has to be valid registration code for the particular LTSS extension.

=item B<fencing> - select fencing mechanism

=item B<fence_type> - select Azure native fencing mechanism. Only two accepted values 'spn' or 'msi'. This argument is only applicable to Azure. (optional)

=item B<spn_application_id> - Application ID for the SPN Azure native fencing agent.This argument is only applicable to Azure configured with native fencing of type SPN. (optional)

=item B<spn_application_password> - password for the SPN Azure native fencing agent.This argument is only applicable to Azure configured with native fencing of type SPN. (optional)

=item B<ptf_files> - list of PTF files (optional)

=item B<ptf_token> - SAS token to access the PTF files (optional)

=item B<ptf_account> - name of the account for the ptf container (optional)

=item B<ptf_container> - name of the container for PTF files (optional)

=item B<ibsm_ip> - IP address of the IBS Mirror  (optional)

=item B<download_hostname> - hostname associated to the IBS Mirror IP address on each hana node (optional)

=item B<repos> - comma separated list of repos (optional)

=back
=cut

sub create_playbook_section_list {
    my (%args) = @_;
    $args{ha_enabled} //= 1;
    $args{registration} //= 'registercloudguest';
    $args{fencing} //= 'sbd';
    $args{scc_code} //= '';

    if ($args{fencing} eq 'native' and is_azure) {
        croak 'Argument <fence_type> missing' unless $args{fence_type};
    }

    if ($args{fencing} eq 'native' and is_azure and $args{fence_type} eq 'spn') {
        croak 'Argument <spn_application_id> missing' unless $args{spn_application_id};
        croak 'Argument <spn_application_password> missing' unless $args{spn_application_password};
    }

    my @playbook_list;

    unless ($args{registration} eq 'noreg') {
        my @reg_args = ('registration.yaml');
        push @reg_args, "-e reg_code=$args{scc_code} -e email_address=''";
        push @reg_args, '-e use_suseconnect=true' if ($args{registration} eq 'suseconnect');
        push @reg_args, qesap_ansible_reg_module(reg => $args{ltss}) if ($args{ltss});
        # Add registration module as first element
        push @playbook_list, join(' ', @reg_args);
    }

    # The presence of ha_enabled is only a trick to detect that
    # code is running in saptune mr_test scenario.
    # For the moment this scenario is ot using Ansible,
    # and the scenario detection is implicitly delegated to this function.
    # No playbooks has to be added in saptune mr_test scenario,
    # to avoid conf.yaml validation failue.
    if ($args{ha_enabled} && $args{ibsm_ip} && $args{download_hostname} && $args{repos}) {
        my @ibsm_args = ('ibsm.yaml');
        push @ibsm_args, "-e ibsm_ip='$args{ibsm_ip}'";
        push @ibsm_args, "-e download_hostname='$args{download_hostname}'";
        push @ibsm_args, "-e repos='$args{repos}'";
        push @playbook_list, join(' ', @ibsm_args);
    }

    unless ($args{registration} eq 'noreg') {
        # Add "fully patch system" module after registration module
        # and before test start/configuration modules.
        # Temporary moved inside noreg condition to avoid test without Ansible to fails.
        # To be properly addressed in the caller and fully-patch-system can be placed back out of the if.
        push @playbook_list, 'fully-patch-system.yaml';
    }

    # Add playbook to download and install PTFs, if any
    if ($args{ptf_files} && $args{ptf_token} && $args{ptf_container} && $args{ptf_account}) {
        push @playbook_list, join(' ',
            'ptf_installation.yaml',
            "-e ptf_files=$args{ptf_files}",
            "-e sas_token='$args{ptf_token}'",
            "-e container=$args{ptf_container}",
            "-e storage=$args{ptf_account}");
    }

    my $hana_cluster_playbook = 'sap-hana-cluster.yaml';
    if ($args{fencing} eq 'native' and is_azure) {
        # Prepares Azure native fencing related arguments for 'sap-hana-cluster.yaml' playbook
        my $azure_native_fencing_args = azure_fencing_agents_playbook_args(
            fence_type => $args{fence_type},
            spn_application_id => $args{spn_application_id},
            spn_application_password => $args{spn_application_password}
        );
        $hana_cluster_playbook = join(' ', $hana_cluster_playbook, $azure_native_fencing_args);
    }

    # SLES4SAP/HA related playbooks
    if ($args{ha_enabled}) {
        push @playbook_list, 'pre-cluster.yaml', 'sap-hana-preconfigure.yaml -e use_sapconf=' . get_var('USE_SAPCONF', 'false');
        push @playbook_list, 'cluster_sbd_prep.yaml' if ($args{fencing} eq 'sbd');
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

=head2 azure_fencing_agents_playbook_args

    azure_fencing_agents_playbook_args(
        fence_type => 'spn'
        spn_application_id=>$spn_application_id,
        spn_application_password=>$spn_application_password
    );

    Collects data and creates string of arguments that can be supplied to playbook.

=over

=item B<FENCE_TYPE> - Azure native fence type (spn|msi)

=item B<SPN_APPLICATION_ID> - application ID that allows API access for STONITH device

=item B<SPN_APPLICATION_PASSWORD> - password provided for application ID above

=back
=cut

sub azure_fencing_agents_playbook_args {
    my (%args) = @_;
    croak 'Argument <fence_type> missing' unless $args{fence_type};
    croak "fence_type contains dubious value: '$args{fence_type}'" unless
      $args{fence_type} =~ /msi|spn/;

    if ($args{fence_type} eq 'spn') {
        foreach ('spn_application_id', 'spn_application_password') {
            croak "Argument < $_ > missing" unless $args{$_};
        }
    }

    my $playbook_opts = "-e azure_identity_management=$args{fence_type}";
    $playbook_opts = join(' ', $playbook_opts,
        "-e spn_application_id=$args{spn_application_id}",
        "-e spn_application_password=$args{spn_application_password}") if $args{fence_type} eq 'spn';

    return ($playbook_opts);
}

=head2 get_hana_site_names

    Get primary and secondary site name.
    This information is both needed to configure the qe-sap-deployment
    and later in the test when calling `hdbnsutil -sr_register`.
    This function mostly read the information from job settings
    HANA_PRIMARY_SITE and HANA_SECONDARY_SITE, so main reason to have
    it behind a function is to have coherent defaults.

=cut

sub get_hana_site_names {
    return (get_var('HANA_PRIMARY_SITE', 'site_a'), get_var('HANA_SECONDARY_SITE', 'site_b'));
}

=head2 create_hana_vars_section

    Detects HANA/HA scenario from openQA variables and create
    data later used for "ansible: hana_vars:" section in config.yaml file.

=cut

sub create_hana_vars_section {
    # Cluster related setup
    my %hana_vars;
    $hana_vars{sap_hana_install_install_execution_mode} = get_var('HANA_INSTALL_MODE') if get_var('HANA_INSTALL_MODE');
    $hana_vars{sap_hana_install_software_directory} = get_required_var('HANA_MEDIA');
    $hana_vars{sap_hana_install_master_password} = get_required_var('_HANA_MASTER_PW');
    $hana_vars{sap_hana_install_sid} = get_required_var('INSTANCE_SID');
    $hana_vars{sap_hana_install_instance_number} = get_required_var('INSTANCE_ID');
    $hana_vars{sap_domain} = get_var('SAP_DOMAIN', 'qesap.example.com');
    $hana_vars{use_sap_hana_sr_angi} = get_var('USE_SAP_HANA_SR_ANGI', 'false');
    $hana_vars{sap_hana_install_update_firewall} = get_var('SLES4SAP_FIREWALL_PORTS', 'false');
    my @hana_sites = get_hana_site_names();
    $hana_vars{primary_site} = $hana_sites[0];
    $hana_vars{secondary_site} = $hana_sites[1];
    set_var('SAP_SIDADM', lc(get_var('INSTANCE_SID') . 'adm'));
    return (\%hana_vars);
}

=head2 display_full_status

    $self->display_full_status()

    Displays most useful debugging info about cluster status, database status within a 'record_info' test entry.

=cut

sub display_full_status {
    my ($self) = @_;
    my $vm_name = $self->{my_instance}{instance_id};
    my $final_message = join("\n", '### CRM STATUS ###',
        $self->run_cmd(cmd => 'crm status', proceed_on_failure => 1),
        '### CRM MON ###',
        $self->run_cmd(cmd => $crm_mon_cmd, proceed_on_failure => 1),
        '### HANA REPLICATION INFO ###',
        $self->run_cmd(cmd => 'SAPHanaSR-showAttr', proceed_on_failure => 1));

    record_info("STATUS $vm_name", $final_message);
}

=head2 list_cluster_nodes

    $self->list_cluster_nodes()

    Returns list of hostnames that are part of a cluster using crm shell command from one of the cluster nodes.

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

=over

=item B<password_db> - password

=item B<instance_id> - instance id

=back
=cut

sub get_hana_database_status {
    my ($self, %args) = @_;
    foreach (qw(password_db instance_id)) { croak("Argument < $_ > missing") unless $args{$_}; }
    my $hdb_cmd = "hdbsql -u SYSTEM -p $args{password_db} -i $args{instance_id} 'SELECT * FROM SYS.M_DATABASES;'";
    my $output_cmd = $self->run_cmd(cmd => $hdb_cmd, runas => get_required_var('SAP_SIDADM'), proceed_on_failure => 1);

    if ($output_cmd =~ /Connection failed/) {
        record_info('HANA DB OFFLINE', "Hana database in primary node is offline. Here the output \n$output_cmd");
        return 0;
    }
    return 1;
}

=head2 is_hana_database_online

    Setup a timeout and check the hana database status is offline and there is not connection.
    If the connection still is online run a wait and try again to get the status.
    Returns 1 if the output of the hana database is online, 0 means that hana database is offline

=over

=item B<timeout> - default 900

=item B<total_consecutive_passes> - default 5

=back
=cut

sub is_hana_database_online {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 900);
    $args{total_consecutive_passes} //= 5;
    my $instance_id = get_required_var('INSTANCE_ID');

    my $db_status = -1;
    my $consecutive_passes = 0;
    my $password_db = get_required_var('_HANA_MASTER_PW');
    my $start_time = time;
    my $hdb_cmd = "hdbsql -u SYSTEM -p $password_db -i $instance_id 'SELECT * FROM SYS.M_DATABASES;'";

    while ($consecutive_passes < $args{total_consecutive_passes}) {
        $db_status = $self->get_hana_database_status(password_db => $password_db, instance_id => $instance_id);
        if (time - $start_time > $timeout) {
            record_info('HANA database after timeout', $self->run_cmd(cmd => $hdb_cmd));
            die('HANA database is still online');
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

=over

=item B<timeout> - default 300

=back
=cut

sub is_primary_node_online {
    my ($self, %args) = @_;
    my $sapadmin = lc(get_required_var('INSTANCE_SID')) . 'adm';

    # Wait by default for 5 minutes
    my $time_to_wait = 300;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    my $cmd = 'python exe/python_support/systemReplicationStatus.py';
    my $output = '';

    # Loop until is not primary the vm01 or timeout is reached
    while ($time_to_wait > 0) {
        $output = $self->run_cmd(cmd => $cmd, runas => $sapadmin, timeout => $timeout, proceed_on_failure => 1);
        if ($output !~ /mode:[\r\n\s]+PRIMARY/) {
            record_info('SYSTEM REPLICATION STATUS', "System replication status in primary node.\n$@");
            return 0;
        }
        $time_to_wait -= 10;
        sleep 10;
    }
    record_info('SYSTEM REPLICATION STATUS', "System replication status in primary node.\n$output");
    return 1;
}

=head2 pacemaker_version

    Returns the pacemaker version

=cut

sub pacemaker_version {
    my ($self) = @_;
    my $version_cmd = 'pacemakerd --version';

    my $version_output = $self->run_cmd(cmd => $version_cmd, quiet => 1);
    record_info('PACEMAKER VERSION', $version_output);

    if ($version_output =~ /Pacemaker (\d+\.\d+\.\d+)/) {
        return $1;
    } else {
        return '';
    }
}

=head2 saphanasr_showAttr_version

    Returns the SAPHanaSR-showattr version

=cut

sub saphanasr_showAttr_version {
    my ($self) = @_;
    # We check a version and also a type of the SAPHanaSR package
    my $which_output = $self->run_cmd(cmd => 'which SAPHanaSR-showAttr', quiet => 1);
    my $version_output = $self->run_cmd(cmd => "rpm -qf $which_output", quiet => 1);
    record_info('SAPHanaSR INFO', "path=$which_output; version=$version_output");

    if ($version_output =~ /(\d+\.\d+(?:\.\d+)*)/) {
        return $1;
    } else {
        return '';
    }
}

=head2 wait_for_cluster

    Verifies that nodes are online, resources are started and DB is in sync

=over

=item B<wait_time> - time to wait before retry in seconds, default 10

=item B<max_retries> - maximum number of retries, default 7

=back
=cut

sub wait_for_cluster {
    my ($self, %args) = @_;

    $args{wait_time} //= 10;
    $args{max_retries} //= 7;
    my $online_str = check_version('>=2.1.7', $self->pacemaker_version()) ? '4' : 'online';

    while ($args{max_retries} > 0) {
        my $crm_output = $self->run_cmd(cmd => $crm_mon_cmd, quiet => 1);

        my $hanasr_ready = check_hana_topology(input => $self->get_hana_topology(), node_state_match => $online_str);
        my $crm_ok = check_crm_output(input => $crm_output);

        if ($hanasr_ready && $crm_ok) {
            record_info('SYNC OK', 'Cluster is healthy: All nodes are online with one node in PRIM and the other in SOK state.');
            return;
        }

        $args{max_retries}--;
        if ($args{max_retries} <= 0) {
            record_info('SYNC FAILED', 'Cluster or DB data synchronization issue detected after retrying.');
            $self->display_full_status();
            # soft fail because of bsc#1233026 - if fixed remove the 'if' condition AND the 'use version_utils' from this file
            if (is_sle('=12-SP5') && $crm_output =~ /TimeoutError/) {
                record_soft_failure('bsc#1233026 - Error occurred, see previous output: Proceeding despite failure.');
                return;
            }
            # Call cleanup_resource if $hanasr_ready or $crm_ok is false
            if (!$hanasr_ready || !$crm_ok) {
                record_soft_failure("jsc#TEAM-10642 SAPHanaSR-ScaleUp-PerfOpt failed in 'Cluster is not ready after specified retries'");
                $self->cleanup_resource();
                $crm_output = $self->run_cmd(cmd => $crm_mon_cmd, quiet => 1);
                return if (check_crm_output(input => $crm_output));
            }
            die('Cluster is not ready after specified retries.');
        }
        sleep($args{wait_time});
    }
}

=head2 wait_for_zypper

    The function attempts to run 'zypper ref' to check for a lock. If Zypper is locked, it waits for a specified delay before retrying.
    Returns normally if Zypper is not locked or dies after a maximum number of retries if Zypper remains locked.

=over

=item B<$instance> - The instance object on which the Zypper command is executed. This object must have the run_ssh_command method implemented.

=item B<max_retries> - The maximum number of times the function will retry checking if Zypper is locked. Default is 10.

=item B<retry_delay> - The number of seconds to wait between retries. Default is 20 seconds.

=item B<timeout> - The number of seconds to wait before aborting zypper ref

=item B<runas> - If 'runas' defined, command will be executed as specified user, otherwise it will be executed as cloudadmin.

=back
=cut

sub wait_for_zypper {
    my ($self, %args) = @_;
    croak('Argument <instance> missing') unless $args{instance};
    $args{max_retries} //= 10;
    $args{retry_delay} //= 20;
    $args{timeout} //= 600;
    $args{runas} //= 'cloudadmin';
    my $retry = 0;

    while ($retry < $args{max_retries}) {
        my $ret = $args{instance}->run_ssh_command(cmd => 'sudo zypper ref',
            username => $args{runas},
            proceed_on_failure => 1,
            rc_only => 1,
            quiet => 1,
            timeout => $args{timeout});
        if ($ret == 7) {
            record_info('ZYPPER LOCK', "Zypper is locked, waiting for the lock to be released. Retry $retry/$args{max_retries}");
            sleep $args{retry_delay};
            $retry++;
        } else {
            record_info('ZYPPER TIMEOUT', "zypper command timed out after $args{timeout} - consider increasing the timeout.") if ($ret == 126);
            record_info('ZYPPER PROBLEM', "Zypper is not locked, but it returned $ret") if ($ret != 0);
            last;
        }
    }

    die("Zypper is still locked after $args{max_retries} retries, aborting (rc: 7)") if $retry >= $args{max_retries};
}

=head2 check_zypper_ref

    The function attempts to run 'zypper ref' and check for errors related to repositories.

=over

=item B<$instance> - The instance object on which the Zypper command is executed. This object must have the run_ssh_command method implemented.

=item B<runas> - If 'runas' defined, command will be executed as specified user, otherwise it will be executed as cloudadmin.

=back
=cut

sub check_zypper_ref {
    my $self = shift;
    my %args = @_;
    $args{runas} //= 'cloudadmin';

    my $ret = $self->{my_instance}->run_ssh_command(cmd => 'sudo zypper ref',
        username => $args{runas},
        proceed_on_failure => 1,
        rc_only => 1,
        quiet => 1,
        timeout => $args{timeout});
    if ($ret == 4) {
        die('ZYPPER: libzypp reported error while refreshing repositories');
    } elsif ($ret == 6) {
        die('ZYPPER reported no repositories defined');
    } elsif ($ret == 106) {
        die('ZYPPER reported some repositories failed to refresh');
    } else {
        record_info('ZYPPER REF', "Zypper ref returned $ret");
    }
}

=head2 wait_for_idle

    The function wraps the `cs_wait_for_idle` command, and restarts in case of timeout (once, this
    time fatal) after displaying cluster information.

=over

=item B<$timeout> - The timeout (in seconds) for the command.

=back
=cut

sub wait_for_idle {
    my ($self, %args) = @_;
    my $timeout = $args{timeout} // 240;

    my $rc = $self->run_cmd_retry(cmd => 'cs_wait_for_idle --sleep 5', timeout => $timeout, rc_only => 1);
    if ($rc == 124) {
        record_info('WARN cs_wait_for_idle', "cs_wait_for_idle timed out after $timeout. Gathering info and retrying");
        $self->run_cmd(cmd => 'cs_clusterstate', proceed_on_failure => 1);
        $self->run_cmd(cmd => 'crm_mon -r -R -n -N -1', proceed_on_failure => 1);
        $self->run_cmd(cmd => 'SAPHanaSR-showAttr', proceed_on_failure => 1);
        # Run again, but allow to fail this time
        $self->run_cmd(cmd => 'cs_wait_for_idle --sleep 5', timeout => $timeout);
    } elsif ($rc != 0) {
        die "Command 'cs_wait_for_idle --sleep 5' failed with return code $rc";
    }
    else {
        record_info('cs_wait_for_idle', 'cs_wait_for_idle completed successfully');
    }
}

1;
