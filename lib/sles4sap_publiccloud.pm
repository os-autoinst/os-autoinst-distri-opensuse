# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Functions for SAP tests

package sles4sap_publiccloud;

use parent 'Exporter';
use strict;
use warnings FATAL => 'all';
use Mojo::Base 'publiccloud::basetest';
use version_utils 'is_sle';
use publiccloud::utils;
use publiccloud::instance;
use testapi;
use List::MoreUtils qw(uniq);
use Data::Dumper;

our @EXPORT = qw(
    run_cmd
    wait_until_resources_started
    upload_ha_sap_logs
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
);

# Global variables
our $crm_mon_cmd = 'crm_mon -R -r -n -N -1';

=head2 run_cmd
    run_cmd(cmd => 'command', [runas => 'user', timeout => 60]);

Runs a command C<cmd> via ssh in the given VM and log the output.
All commands are executed through C<sudo>.
If 'runas' defined, command will be executed as specified user,
otherwise it will be executed as root.

=cut
sub run_cmd {
    my ($self, %args) = @_;
    die('Argument <cmd> missing') unless ($args{cmd});
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);
    my $title = $args{title} // $args{cmd};
    $title =~ s/[[:blank:]].+// unless defined $args{title};
    my $cmd = defined($args{'runas'}) ? "su - $args{'runas'} -c '$args{cmd}'" : "$args{cmd}";

    # Without cleaning up variables SSH commands get executed under wrong user
    delete($args{cmd});
    delete($args{title});
    delete($args{timeout});
    delete($args{runas});

    my $out = $self->{my_instance}->run_ssh_command(cmd => "sudo $cmd", timeout => $timeout, %args);
    record_info("$title output - $self->{my_instance}->{instance_id}", $out) unless ($timeout == 0 or $args{quiet} or $args{rc_only});
    return $out;
}

=head2 wait_until_resources_started

    wait_until_resources_started( [ timeout => $timeout ] );

Wait for resources to be started. Runs C<crm cluster wait_for_startup> in SUT as well
as other verifications on newer versions of SLES (12-SP3+), for up to B<$timeout> seconds
for each command. Timeout must be specified by the named argument B<timeout> (defaults
to 120 seconds). This timeout is scaled by the factor specified in the B<TIMEOUT_SCALE>
setting. Croaks on timeout.
=cut
sub wait_until_resources_started {
    my ($self, %args) = @_;
    my @cmds = ('crm cluster wait_for_startup');
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 60);
    # At least one node needs to be online
    push @cmds, "$crm_mon_cmd | grep -q Node\\ .*\\ online:";

    # HANA cluster doesn't restart all resources after fencing in some configurations
    record_info('Cluster type, wait', $args{cluster_type});
    if ($args{cluster_type} ne 'hana') {
        # Some CRM options can only been added on recent versions
        push @cmds, "$crm_mon_cmd | grep -iq no\\ inactive\\ resources" if is_sle '12-sp3+';
        # This code is a little bit complicated, but we have to invert the RC for the while loop
        push @cmds, "$crm_mon_cmd | grep -iq starting && RC=false || RC=true; eval \$RC";
    }

    # Execute each comnmand to validate that the cluster is running
    # This can takes time, so a loop is a good idea here
    foreach my $cmd (@cmds) {
        # Each command execution has its own timeout, so we need to reset the counter
        my $start_time = time;

        # Check for cluster/resources status and exit loop when needed
        while ($self->run_cmd(cmd => "$cmd", rc_only => 1)) {
            # Otherwise wait a while if timeout is not reached
            if (time - $start_time < $timeout) {
                sleep 5;
            }
            else {
                # Cluster doesn't start properly, show state before dying
                $self->run_cmd(cmd => $crm_mon_cmd);
                die "Cluster/resources did not start within $timeout seconds (cmd='$cmd')";
            }
        }
    }
}

=head2 upload_ha_sap_logs

    upload_ha_sap_logs($instance):

Upload the HA/SAP logs from instance C<$instance> on the Webui.
=cut
sub upload_ha_sap_logs {
    my ($self, $instance) = @_;
    my @logfiles = qw(salt-deployment.log salt-os-setup.log salt-pre-deployment.log salt-result.log);

    # Upload logs from public cloud VM
    $instance->run_ssh_command(cmd => 'sudo chmod o+r /var/log/salt-*');
    foreach my $file (@logfiles) {
        $instance->upload_log("/var/log/$file", log_name => "$instance->{instance_id}-$file");
    }
}


=head2 get_promoted_hostname()
    get_promoted_hostname();

Checks and returns hostname of HANA promoted node.
=cut
sub get_promoted_hostname {
    my ($self) = @_;
    my $resource_output = $self->run_cmd(cmd => "crm resource status msl_SAPHana_PRD_HDB00", quiet => 1);
    record_info("crm out", $resource_output);
    my @master = $resource_output =~ /:\s(\S+)\sMaster/g;
    if ( scalar @master != 1 ) {
        diag("Master database not found or command returned abnormal output.\n
        Check 'crm resource status' command output below:\n");
        diag($resource_output);
        die("Master database was not found, check autoinst.log");
    }

    return join("", @master);
}

=head2 get_hana_topology
    get_hana_topology([hostname => $hostname]);
    Parses  command output, returns list of hashes containing values for each host.
    If hostname defined, returns hash with values only for host specified.
=cut
sub get_hana_topology {
    my ($self, %args) = @_;
    my @topology;
    my $hostname = $args{hostname};
    my $cmd_out = $self->run_cmd(cmd => "SAPHanaSR-showAttr --format=script", quiet => 1);
    record_info("cmd_out", $cmd_out);
    my @all_parameters = map { if (/^Hosts/) {s,Hosts/,,; s,",,g; $_} else { () } } split("\n", $cmd_out);
    my @all_hosts = uniq map { (split("/", $_))[0] } @all_parameters;

    for my $host (@all_hosts) {
        my %host_parameters = map { my($node, $parameter, $value) = split(/[\/=]/, $_);
            if ($host eq $node) {($parameter, $value)} else { () } } @all_parameters;
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
    my $wait_for_start = defined($args{wait_for_start}) ? 1 : 0;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 120);
    my $start_time = time;
    my $db_status = 0;

    while ($db_status != 1) {
        $db_status = 1 if ($self->get_replication_info()->{online} eq "true");
        last if $wait_for_start == 0;
        die("DB did not start within defined timeout: $timeout s") if (time - $start_time > $timeout);
        sleep 30;
    }
    return $db_status;
}


=head2 is_hana_resource_running
    is_hana_resource_running([timeout => 60]);

Checks if resource msl_SAPHana_PRD_HDB00 is running on given node.
=cut
sub is_hana_resource_running {
    my ($self) = @_;
    my $hostname = $self->{my_instance}->{instance_id};

    my $resource_output = $self->run_cmd(cmd => "crm resource status msl_SAPHana_PRD_HDB00", quiet => 1);
    my $node_status = grep /is running on: $hostname/, $resource_output;
    record_info("Node status", "$hostname: $node_status");
    return $node_status;
}

=head2 stop_hana
    hana_stop_and_wait();

Stops hana database using method specified and waits for resources being stopped.
Default method is 'stop = HDB stop'
Methods available:
  stop = HDB stop
  kill = HDB kill -x
  crash = proc-systrigger

=cut
sub stop_hana {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    my $method = defined($args{method}) ? $args{method} : 'stop';
    my %commands = (
        "stop"  => "HDB stop",
        "kill"  => "HDB kill -x",
        "crash" => "sync; echo b | tee /proc/sysrq-trigger > /dev/null &"
    );

    my $cmd = $commands{$method};

    # wait for data sync before stopping DB
    $self->wait_for_sync();

    record_info("Stopping HANA", "CMD:$cmd");
    if ($method eq "crash") {
        $self->{my_instance}->run_ssh_command(cmd => "sudo $cmd", timeout => "0", %args);
        #$self->run_cmd(cmd => $cmd, timeout => $timeout);
        sleep 30;
        $self->{my_instance}->wait_for_ssh();
        return();
    }
    else {
        $self->run_cmd(cmd => $cmd, runas=>"prdadm" , timeout => $timeout);
    }

    # Wait for resource to stop
    my $start_time = time;
    while ($self->is_hana_resource_running() == 1) {
        if (time - $start_time > $timeout){
            record_info("Cluster status", $self->run_cmd(cmd => $crm_mon_cmd));
            die("DB stop operation timed out($timeout sec).");
        }
        sleep 30;
    }
}

=head2 start_hana
    start_hana([timeout => 60]);

Start HANA DB using "HDB start" command

=cut

sub start_hana{
    my ($self) = @_;
    $self->run_cmd(cmd => "HDB start", runas=>"prdadm");
}

=head2 cleanup_resource
    cleanup_resource([timeout => 60]);

Cleanup rsource 'msl_SAPHana_PRD_HDB00', wait for DB start automaticlly.

=cut

sub cleanup_resource{
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    $self->run_cmd(cmd => "crm resource cleanup msl_SAPHana_PRD_HDB00");

    # Wait for resource to start
    my $start_time = time;
    while ($self->is_hana_resource_running() == 0) {
        if (time - $start_time > $timeout){
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
# TODO: Check if takeover happened
sub check_takeover {
    my ($self) = @_;
    my $hostname = $self->{my_instance}->{instance_id};
    my $takeover_complete = 0;
    my $fenced_hana_status = $self->is_hana_online();
    die("Fenced database '$hostname' is not offline") if ($fenced_hana_status == 1);

    while ($takeover_complete == 0) {
        my $topology = $self->get_hana_topology();

        for my $entry (@$topology) {
            my %host_entry = %$entry;
            my $sync_state = $host_entry{sync_state};
            my $takeover_host = $host_entry{vhost};

            if ($takeover_host ne $hostname && $sync_state eq "PRIM") {
                $takeover_complete = 1;
                record_info("Takeover status:", "Takeover complete to node '$takeover_host'" );
                last;
            }
            sleep 30;
        }
    }

    return 1;
}

=head2 register_hana
    register_hana();

=cut
sub enable_replication {
    my ($self) = @_;
    my $hostname = $self->{my_instance}->{instance_id};
    my $topology_out = $self->get_hana_topology(hostname => $hostname);
    my %topology = %$topology_out;

    record_info("Topology", Dumper($topology_out));

    my $cmd = "hdbnsutil -sr_register " .
    "--name=$topology{vhost} " .
    "--remoteHost=$topology{remoteHost} " .
    "--remoteInstance=00 " .
    "--replicationMode=$topology{srmode} " .
    "--operationMode=$topology{op_mode}";

    record_info('CMD Run', $cmd);
    $self->run_cmd(cmd => $cmd, runas => "prdadm");

}

=head2 get_replication_info
    get_replication_info();
    Parses hdbnsutil command output.
    Returns hash of found values converted to lowercase and replaces spaces to underscores.
=cut
sub get_replication_info {
    my ($self) = @_;
    my $output_cmd = $self->run_cmd(cmd => "hdbnsutil -sr_state| grep -E :[^\^]", runas => "prdadm");

    # Create a hash from hdbnsutil output ,convert to lowercase with underscore instead of space.
    my %out = $output_cmd =~ /^?\s?([\/A-z\s]*\S+):\s(\S+)\n/g;
    %out = map { $_ =~ s/\s/_/g; lc $_} %out;
    return \%out;
}


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
        die("Failed to identify Hana 'PROMOTED' node") ;
    }

    return $promoted;
}

=head2 wait_for_sync
    wait_for_sync();
    Wait for replica site to sync data with primary.
    Checks "SAPHanaSR-showAttr" output and ensures replica site has "sync_state" "SOK".
=cut
sub wait_for_sync {
    my ($self, %args) = @_;
    my $timeout = bmwqemu::scale_timeout($args{timeout} // 300);
    my $sok = 0;
    record_info("Sync wait", "Waiting for data sync between nodes");

    # Check sync status periodically until ok or timeout
    my $start_time = time;

    while ($sok == 0) {
        my $topology = $self->get_hana_topology();
        for my $entry (@$topology) {
            my %entry = %$entry;
            $sok = 1 if $entry{sync_state} eq "SOK";
            last if $sok == 1;
        }

        if (time - $start_time > $timeout){
            record_info("Cluster status", $self->run_cmd(cmd => $crm_mon_cmd));
            record_info("Sync FAIL", "Host replication status: " . run_cmd(cmd=>'SAPHanaSR-showAttr'));
            die("Replication SYNC did not finish within defined timeout. ($timeout sec).");
        }
        sleep 30;
    }
    record_info("Sync OK", $self->run_cmd(cmd=>"SAPHanaSR-showAttr"));
    return 1;
}

1;